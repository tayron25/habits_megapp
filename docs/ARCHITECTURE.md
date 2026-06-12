# Arquitectura

El repositorio contiene dos aplicaciones Flutter independientes dentro de un mismo ecosistema.

## Componentes

- `app/`: Life OS. Registra productividad personal, habitos, tareas, notas, areas de vida y roadmaps.
- `gym/`: Gym Tracker. Registra entrenamientos, plantillas, series, progresion y calendario.
- Supabase: backend compartido para autenticacion, persistencia remota y futuras analiticas cruzadas.

## Stack

- Flutter / Dart para UI multiplataforma.
- Riverpod con `riverpod_annotation` y generacion de codigo para estado.
- Drift sobre SQLite como fuente de verdad local.
- Supabase Auth y PostgreSQL como backend remoto.
- `uuid` para IDs generados localmente.

## Offline-First

La base local es la fuente de verdad de la UI. Las pantallas observan datos con Streams de Drift y Riverpod. Al crear, editar o borrar una entidad, el cambio se aplica primero en SQLite y luego se intenta sincronizar con Supabase.

Cada entidad sincronizada usa:

- `id` generado localmente.
- `isSynced` para marcar cambios pendientes.
- `user_id` en Supabase para aislar datos por cuenta.

## Separacion App/Gym

Gym fue extraido de Life OS para mantener una experiencia de entrenamiento rapida y especializada. Ambas apps comparten Supabase, pero cada una mantiene su propio esquema local Drift y su propia UI.

La integracion futura debe ocurrir por analiticas y datos remotos compartidos, no por dependencias directas entre paquetes Flutter.

## Reglas de Codigo

- Usar imports absolutos: `package:app/...` y `package:gym/...`.
- Evitar imports relativos entre archivos con codigo generado.
- Al crear providers de Stream con listas Drift, usar typedefs para evitar tipos genericos anidados en `build()`.
- Recordar que un notifier `TareasNotifier` genera un provider llamado `tareasProvider`, no `tareasNotifierProvider`.

