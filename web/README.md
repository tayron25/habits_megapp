# Life OS Web

Panel de diagnostico personal del ecosistema Life OS. La web es solo lectura y consume Supabase con usuarios autenticados, respetando RLS por `user_id`.

## Stack

- Next.js App Router.
- React / TypeScript.
- Tailwind CSS con componentes estilo shadcn/ui.
- Supabase JS + `@supabase/ssr`.
- Recharts para visualizaciones.
- Zod para validar variables de entorno.

## Variables de Entorno

Crea `.env.local` desde `.env.example`:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

No usar service role key en la web.

## Ejecutar

```bash
npm install
npm run dev
```

La app abre en `http://localhost:3000`.

## Verificacion

```bash
npm run lint
npm run build
```

## Deploy

Deploy recomendado: Vercel.

Configurar las mismas variables de entorno en el proyecto de Vercel. Supabase debe tener RLS habilitado y permisos para `authenticated`.

## Alcance

- Login con Supabase email/password.
- Dashboard autenticado.
- Filtros por rango de fechas y area de vida.
- Diagnostico semanal con score explicable.
- Patrones que ayudan y patrones que perjudican.
- Mapa de areas de vida: accion, carga mental, progreso y friccion.
- Calendario heatmap de comportamiento.
- Cruce Gym + Vida.
- Roadmaps con progreso y estancamiento.
- Eventos relevantes desde `activity_events`.
- Solo lectura: no crea, edita ni elimina datos.

## Supabase

Antes de usar el dashboard, aplicar las migraciones de analitica:

- `../docs/supabase_life_os_analytics_migration.sql`

Si faltan tablas o columnas, la UI muestra un aviso de datos parciales.
