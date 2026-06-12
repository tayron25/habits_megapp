# Sincronizacion Offline-First

La sincronizacion esta disenada para que las apps funcionen aun sin conexion. La UI nunca depende directamente de una respuesta remota para mostrar el estado principal.

## Flujo Base

1. La UI observa SQLite local con Drift.
2. El usuario crea, edita o borra datos.
3. El cambio se aplica primero localmente.
4. La entidad queda con `isSynced = false` o se registra una accion pendiente.
5. La app intenta sincronizar con Supabase.
6. Si el sync remoto funciona, el registro local pasa a `isSynced = true`.

## Campos Comunes

- `id`: generado localmente con UUID.
- `isSynced`: indica si el registro local ya fue enviado al backend.
- `createdAt`: fecha de creacion local.
- `user_id`: existe en Supabase para aislar datos por cuenta.

## Deletes

Para borrados offline se usa una cola local de acciones pendientes, por ejemplo `PendingSyncActions`.

El patron es:

1. Registrar accion pendiente `DELETE`.
2. Borrar localmente para que la UI responda de inmediato.
3. Intentar borrar en Supabase.
4. Si funciona, eliminar la accion pendiente.
5. Si falla, reintentar en sincronizaciones futuras.

## Sync Pull

Life OS usa un pull por niveles para respetar dependencias:

- Nivel 1: entidades base, como areas de vida.
- Nivel 2: entidades padre, como habitos, tareas, notas y roadmaps.
- Nivel 3: entidades dependientes, como logs o milestones.
- Nivel 4: entidades dependientes de entidades dependientes, como tareas de milestones.

Gym Tracker mantiene su propio pull/push para entidades de gimnasio.

## Riesgos a Vigilar

- Conflictos entre dos dispositivos editando el mismo registro.
- Deletes que ocurren offline en un dispositivo mientras otro edita.
- Migraciones locales despues de separar modulos.
- Fechas guardadas como UTC cuando conceptualmente son fechas locales.

