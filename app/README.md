# Life OS

Aplicacion movil de productividad personal orientada a registrar datos del dia a dia y convertirlos en analitica accionable. Life OS es la app principal del ecosistema: captura habitos, tareas, notas, areas de vida y roadmaps.

Gym Tracker fue extraido a `../gym` como aplicacion independiente, pero ambas apps comparten Supabase para autenticacion, sincronizacion y futuras analiticas cruzadas.

## Stack

- Flutter / Dart.
- Riverpod con generacion de codigo.
- Drift sobre SQLite como base local.
- Supabase Auth y PostgreSQL como backend remoto.
- Arquitectura offline-first.

## Arquitectura Local

La UI lee desde SQLite local usando Streams y Riverpod. Las escrituras se aplican primero en Drift y luego se intentan subir a Supabase. Las entidades sincronizadas usan IDs locales con UUID y un campo `isSynced`.

El esquema local esta en la version 15 y contiene:

- `LifeAreas`: areas de vida.
- `Notes`: capturas rapidas.
- `Habits`: habitos avanzados.
- `HabitLogs`: registros diarios de habitos.
- `Tasks`: tareas puntuales.
- `Roadmaps`: metas de largo plazo.
- `RoadmapMilestones`: hitos de roadmaps.
- `MilestoneTasks`: checklist de hitos.
- `PendingSyncActions`: cola de acciones offline.
- `activity_events`: linea de tiempo analitica comun para acciones importantes.

## Modulos

- Areas de vida: categorizacion transversal para habitos, tareas y analiticas.
- Habitos V3: vigencia, frecuencia, metas por periodo, horario y area asociada.
- Tareas: prioridad, fecha de vencimiento opcional, fecha planificada, origen, relacion con areas de vida y cierre como hecha/no hecha sin borrar historial.
- Notas/Ideas: captura rapida sin categorizar. Al procesarlas se pueden asociar a un area de vida o descartar de la bandeja, pero quedan registradas como log y pueden rastrear conversion futura a otras entidades.
- Roadmaps: metas, hitos y tareas para medir avance. Preparados para asociarse a areas de vida y guardar `completed_at` en tareas de milestone.
- Autenticacion y sync: sesiones Supabase, push/pull y cola offline.

## Datos y Analitica

Life OS guarda datos pensando en analisis futuro:

- Todas las entidades principales usan UUID, `created_at`, sync offline y `user_id` remoto.
- `life_area_id` funciona como dimension transversal para habitos, tareas, notas y roadmaps.
- Las acciones de cierre conservan estado y fecha: tareas `done/missed`, notas `categorized/discarded`, tareas de roadmap `done/active`.
- `activity_events` registra eventos como `habit_completed`, `task_done`, `task_missed`, `note_captured` y `roadmap_task_completed`.
- La app separa fechas de intencion y ejecucion cuando importa: por ejemplo `planned_date` vs `completed_at`, y `target_date` vs `logged_at` en habitos.

## Pantalla Principal

La pantalla Hoy muestra informacion relevante para el dia actual. Los habitos se filtran reactivamente para no mostrar habitos expirados o que no corresponden al dia. El `FloatingActionButton` centraliza la creacion de entidades mediante modales.

## Como Ejecutar

```bash
flutter pub get
dart run build_runner build -d
flutter run
```

Ejecuta `dart run build_runner build -d` cuando cambies tablas Drift o providers con generacion.

## Documentacion Relacionada

- [Arquitectura general](../docs/ARCHITECTURE.md)
- [Supabase y RLS](../docs/SUPABASE.md)
- [Sincronizacion](../docs/SYNC.md)
- [Roadmap](../docs/ROADMAP.md)

## Reglas de Desarrollo

- Actualizar este README o `docs/` cuando cambie una feature, estructura o decision importante.
- Usar imports absolutos: `package:app/...`.
- No agregar codigo de gimnasio dentro de `app/`; Gym vive en `../gym`.
- Los scripts SQL deben usar `authenticated`, RLS habilitado y politicas por `user_id`.
