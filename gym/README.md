# Gym Tracker

Aplicacion independiente para registro avanzado de entrenamientos de fuerza dentro del ecosistema Life OS. Comparte Supabase con la app principal para autenticacion, sincronizacion y futuras analiticas cruzadas, pero mantiene su propia UI y base local.

## Proposito

Gym Tracker esta disenada con una filosofia de cero friccion: abrir la app debe llevar al entrenamiento programado para hoy, con la menor navegacion posible y sugerencias basadas en historial.

## Funcionalidades

- Entrenamiento del dia como flujo principal.
- Vista de entrenamiento con chrome ocultable al hacer scroll para reducir friccion.
- Plantillas de entrenamiento.
- Ejercicios por plantilla.
- Creacion y edicion de rutinas desde el planner del calendario.
- Reorden visual de ejercicios durante una sesion, sin modificar la plantilla original.
- Registro de sesiones y series.
- Notas por serie.
- Maximo historico por ejercicio:
  - Si hay peso, prioriza mayor carga.
  - Si no hay peso, prioriza mayor cantidad de repeticiones.
  - En empates, usa reps y fecha reciente como desempate.
- Progresion por rangos:
  - Bajo: fuerza, 8 a 12 reps.
  - Alto: hipertrofia, 12 a 16 reps.
  - Manual: sin progresion automatica.
- Calendario semanal compacto con chips de rutinas.
- Panel unico de planificacion para elegir, crear, cambiar, mover y borrar rutinas.
- Seleccion multiple de dias para borrar planificaciones.
- Generador de patrones.
- Auto-shift para desplazar entrenamientos pendientes si se falta un dia:
  - Pendientes vencidos se mueven hacia la derecha hasta hoy.
  - Al adelantar una rutina, los entrenamientos pendientes posteriores se mueven hacia la izquierda.
  - Al retrasar una rutina, los entrenamientos pendientes posteriores se mueven hacia la derecha.
- Sincronizacion bidireccional con Supabase.

## UX Principal

La app prioriza continuidad y cero friccion:

- Al abrir, la experiencia principal es entrenar hoy o ver la semana actual.
- El calendario no funciona como agenda pesada; funciona como una cadena flexible de entrenamientos.
- Si se incumple un dia, el plan se conserva y se desplaza.
- Si se adelanta un entrenamiento, la cadena pendiente se compacta hacia adelante.
- Los entrenamientos completados no se arrastran para proteger el historial real.

## Stack

- Flutter / Dart.
- Riverpod con generacion de codigo.
- Drift sobre SQLite como base local.
- Supabase Auth y PostgreSQL como backend remoto.
- Arquitectura offline-first.

## Base de Datos Local

El esquema local esta especializado en gimnasio:

- `WorkoutTemplates`: plantillas.
- `TemplateExercises`: ejercicios de plantillas y reglas de progresion.
- `WorkoutLogs`: sesiones historicas o en progreso.
- `WorkoutSets`: series individuales.
- `PlannedWorkouts`: entrenamientos planificados.
- `PlannedExercises`: ejercicios planificados.
- `PendingSyncActions`: acciones offline pendientes.

## Supabase

Gym Tracker usa el mismo backend que Life OS. Las tablas remotas deben usar `authenticated`, RLS habilitado y `user_id` para aislar datos por cuenta.

Ver [Supabase y seguridad](../docs/SUPABASE.md).

## Como Ejecutar

```bash
flutter pub get
dart run build_runner build -d
flutter run
```

Ejecuta `dart run build_runner build -d` cuando cambies tablas Drift o providers con generacion.

## Documentacion Relacionada

- [Arquitectura general](../docs/ARCHITECTURE.md)
- [Sincronizacion](../docs/SYNC.md)
- [Decisiones tecnicas](../docs/DECISIONS.md)
- [Roadmap](../docs/ROADMAP.md)

## Reglas de Desarrollo

- Actualizar este README o `docs/` cuando cambie una feature, estructura o decision importante.
- Usar imports absolutos: `package:gym/...`.
- No depender directamente de codigo de `../app`; la integracion entre apps pasa por Supabase y analiticas.
- Los scripts SQL deben usar RLS por usuario, nunca permisos amplios a `anon`.
