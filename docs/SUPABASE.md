# Supabase y Seguridad

Supabase es el backend compartido del ecosistema. Se usa para autenticacion, persistencia remota y sincronizacion entre dispositivos.

## Regla Principal

Todo se trabaja con usuarios autenticados. No se deben dar permisos de escritura al rol `anon` ni desactivar RLS para tablas de datos de usuario.

Cada persona debe tener acceso completo solo a los datos de su propia cuenta.

## Patron Obligatorio para Tablas de Usuario

Todas las tablas sincronizadas deben incluir:

```sql
user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL
```

Y deben seguir este patron:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON public.<nombre_tabla> TO authenticated;
ALTER TABLE public.<nombre_tabla> ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own <nombre_tabla>"
ON public.<nombre_tabla>
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

## Notas

- `anonKey` o `publishableKey` en Flutter es una credencial publica del cliente, no una autorizacion para mezclar datos entre usuarios.
- Las politicas RLS son la barrera real de aislamiento multi-tenant.
- Los inserts y updates deben enviar `user_id` con el ID del usuario autenticado.
- Los pulls desde Supabase pueden usar `.select()` si RLS esta bien configurado, porque Supabase filtrara por politica.

## Scripts SQL

Los scripts deben ser idempotentes cuando sea razonable:

- `CREATE TABLE IF NOT EXISTS`.
- `ADD COLUMN IF NOT EXISTS`.
- `GRANT` explicito a `authenticated`.
- RLS habilitado.
- Politicas con `USING` y `WITH CHECK`.

## Migraciones Actuales

Notas/Ideas ahora conservan el historial aunque desaparezcan de la bandeja rapida. La tabla remota `notes` debe incluir:

```sql
ALTER TABLE public.notes
ADD COLUMN IF NOT EXISTS life_area_id UUID REFERENCES public.life_areas(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'captured',
ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS converted_to_type TEXT,
ADD COLUMN IF NOT EXISTS converted_to_id UUID,
ADD COLUMN IF NOT EXISTS note_type TEXT;
```

Estados esperados:

- `captured`: pensamiento visible en Ideas.
- `categorized`: pensamiento procesado y asociado a un area de vida.
- `discarded`: pensamiento quitado de Ideas sin area, conservado como log.

Campos analiticos:

- `converted_to_type` / `converted_to_id`: permiten medir si una nota termino convertida en tarea, habito, roadmap u otra entidad.
- `note_type`: permite separar captura rapida, reflexion, preocupacion, idea u otros tipos futuros sin romper la nota rapida.

Tareas ahora tambien conservan historial al salir de la vista activa. La tabla remota `tasks` debe incluir:

```sql
ALTER TABLE public.tasks
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS planned_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS missed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS origin_type TEXT,
ADD COLUMN IF NOT EXISTS origin_id UUID;
```

Estados esperados:

- `active`: tarea visible en la vista principal.
- `done`: tarea procesada como hecha.
- `missed`: tarea procesada como no hecha.

Campos analiticos:

- `planned_date`: cuando se esperaba hacer la tarea, distinto a `due_date` cuando aplique.
- `completed_at` y `missed_at`: separan el cierre positivo del negativo.
- `origin_type` y `origin_id`: permiten medir si una tarea nacio de una nota, roadmap, habito, captura manual u otra fuente.

Roadmaps pueden decidir si empujan su siguiente accion a la pantalla Hoy:

```sql
ALTER TABLE public.roadmaps
ADD COLUMN IF NOT EXISTS show_on_home BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS life_area_id UUID REFERENCES public.life_areas(id) ON DELETE SET NULL;
```

Tareas de roadmap deben guardar historia de avance, no solo estado actual:

```sql
ALTER TABLE public.milestone_tasks
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
```

Logs de habitos deben guardar el dia objetivo y el momento real de registro:

```sql
ALTER TABLE public.habit_logs
ADD COLUMN IF NOT EXISTS target_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'done',
ADD COLUMN IF NOT EXISTS logged_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS amount INTEGER,
ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';
```

Estados esperados de `habit_logs`:

- `done`: habito cumplido.
- `missed`: fallo explicito futuro.
- `skipped`: omitido conscientemente futuro.

## Eventos Analiticos

Para analitica cruzada entre Life OS, Gym y futuras apps, usar una tabla comun de eventos:

```sql
CREATE TABLE IF NOT EXISTS public.activity_events (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  life_area_id UUID REFERENCES public.life_areas(id) ON DELETE SET NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  local_date DATE NOT NULL,
  source_app TEXT NOT NULL DEFAULT 'life_os',
  metadata_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_events TO authenticated;
ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own activity_events"
ON public.activity_events
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

Eventos iniciales emitidos por la app:

- `note_captured`, `note_categorized`, `note_discarded`, `note_deleted_error`.
- `task_created`, `task_done`, `task_missed`, `task_deleted_error`.
- `habit_created`, `habit_completed`, `habit_uncompleted`.
- `roadmap_created`, `roadmap_task_completed`, `roadmap_task_reopened`.

Despues de aplicar migraciones en Supabase, refrescar cache de PostgREST:

```sql
NOTIFY pgrst, 'reload schema';
```
