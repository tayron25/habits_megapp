# Decisiones Tecnicas

Registro corto de decisiones importantes para que el proyecto mantenga contexto entre sesiones.

## Gym se separa de Life OS

Gym Tracker fue extraido de la app principal porque el entrenamiento necesita una experiencia mas directa, rapida y especializada. La app de gimnasio debe abrir en el flujo del entrenamiento del dia, no en una pantalla general de productividad.

Consecuencias:

- `app/` ya no debe contener UI, providers ni tablas locales propias de gimnasio.
- `gym/` mantiene su propio esquema Drift y su propia navegacion.
- La integracion futura ocurre por Supabase y analiticas, no por imports cruzados entre apps.

## Supabase Compartido

Ambas apps comparten backend para permitir:

- Una cuenta de usuario comun.
- Sincronizacion multi-dispositivo.
- Analiticas futuras cruzando productividad y entrenamiento.

La seguridad se basa en RLS con `authenticated` y `user_id`.

## Offline-First

La decision de offline-first prioriza velocidad y confiabilidad de captura. La UI debe poder funcionar aunque Supabase falle temporalmente.

## Calendario Flexible en Gym

El calendario de Gym Tracker se trata como una cadena flexible de entrenamientos pendientes, no como una agenda fija.

Reglas actuales:

- Si hay entrenamientos pendientes en dias pasados, se desplazan hacia la derecha hasta que el pendiente mas antiguo quede en hoy.
- Al mover una rutina pendiente a una fecha anterior, todos los pendientes posteriores se desplazan hacia la izquierda por la misma cantidad de dias.
- Al mover una rutina pendiente a una fecha posterior, todos los pendientes posteriores se desplazan hacia la derecha.
- Los entrenamientos completados no se arrastran automaticamente para preservar el historial real.

Esta decision evita que el usuario tenga que replanificar manualmente despues de faltar o adelantar dias.

## Planner Unico en Gym

La planificacion de Gym Tracker se centraliza en un panel unico desde el calendario. Desde ahi se puede elegir rutina, crear rutina, cambiar una rutina planificada, moverla o borrarla.

El objetivo es evitar modales apilados y mantener el flujo de planificacion en un solo contexto.

## README como Mapa, Docs como Verdad Tecnica

Los README deben orientar rapido. Las reglas profundas viven en `docs/`:

- `docs/ARCHITECTURE.md`
- `docs/SUPABASE.md`
- `docs/SYNC.md`
- `docs/DECISIONS.md`
- `docs/ROADMAP.md`
