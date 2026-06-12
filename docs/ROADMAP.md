# Roadmap

## Prioridad Alta

- Estabilizar sincronizacion multi-dispositivo.
- Revisar RLS y politicas Supabase para todas las tablas existentes.
- Mantener separacion limpia entre `app/` y `gym/`.
- Definir el primer tablero analitico minimo.
- Iniciar fase web del ecosistema.

## Life OS

- Mejorar analiticas de habitos por semana, mes y area de vida.
- Cruzar tareas completadas con areas de vida.
- Dar mas valor a roadmaps con progreso historico.
- Reducir deuda de lints: `print`, `withOpacity`, `BuildContext` despues de awaits.

## Gym Tracker

- Pulir progresion por rangos.
- Refinar microinteracciones del calendario y planner.
- Mejorar lectura del historial para sugerencias de peso/reps.
- Conectar datos de gimnasio con analiticas de Life OS.

Hecho en la primera pasada de UX:

- Calendario semanal compacto.
- Planner unico para elegir, crear, cambiar, mover y borrar rutinas.
- Borrado multiple de planificaciones.
- Auto-shift de pendientes vencidos.
- Movimiento en cadena al adelantar o retrasar entrenamientos pendientes.
- Maximo historico por peso o reps cuando no hay carga.
- Reorden visual de ejercicios durante una sesion.
- Chrome superior ocultable durante entrenamiento.

## Web

Siguiente fase del proyecto. La web debe respetar la separacion entre `app/` y `gym/`, compartir Supabase con RLS por usuario autenticado y priorizar vistas de analitica, administracion o uso complementario a las apps moviles.

## Analitica Personal

Primer objetivo recomendado:

- Resumen semanal por area de vida.
- Habitos cumplidos.
- Tareas cerradas.
- Entrenamientos hechos.
- Tendencia simple contra la semana anterior.
