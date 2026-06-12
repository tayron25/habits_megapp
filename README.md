# Life OS Ecosystem

Ecosistema de aplicaciones Flutter para registrar, organizar y analizar datos personales del dia a dia. El proyecto esta dividido en dos apps independientes que comparten el mismo backend Supabase para permitir autenticacion comun, sincronizacion y futuras analiticas cruzadas.

## Apps

- `app/`: Life OS, app principal de productividad personal, habitos, tareas, notas, areas de vida y roadmaps.
- `gym/`: Gym Tracker, app especializada para entrenamientos de fuerza, planificacion, progresion y registro de series.
- `web/`: dashboard analitico web, solo lectura, para cruzar datos de Life OS y Gym desde Supabase.

## Fase Actual

- Gym Tracker: primera pasada de UX principal completada en calendario, planner y entrenamiento.
- Siguiente foco: web del ecosistema, respetando Supabase compartido, RLS por usuario autenticado y separacion limpia entre apps.

## Arquitectura General

- Frontend movil: Flutter / Dart.
- Frontend web: Next.js / React / TypeScript.
- Estado: Riverpod con generacion de codigo.
- Base local: Drift sobre SQLite.
- Backend remoto: Supabase Auth y PostgreSQL.
- Filosofia: offline-first. La UI lee de SQLite local, las escrituras ocurren primero localmente y luego se sincronizan con Supabase.

## Documentacion

- [Arquitectura](docs/ARCHITECTURE.md)
- [Supabase y seguridad](docs/SUPABASE.md)
- [Sincronizacion offline-first](docs/SYNC.md)
- [Decisiones tecnicas](docs/DECISIONS.md)
- [Roadmap](docs/ROADMAP.md)

## Reglas Globales

- Cada cambio estructural o feature debe reflejarse en la documentacion correspondiente.
- Los scripts SQL de Supabase trabajan con `authenticated`, RLS habilitado y datos aislados por `user_id`.
- Usar importaciones absolutas en Dart: `package:app/...` o `package:gym/...`.
- Si se modifican tablas Drift o providers generados, ejecutar `dart run build_runner build -d`.

## Como Ejecutar

Life OS:

```bash
cd app
flutter pub get
flutter run
```

Gym Tracker:

```bash
cd gym
flutter pub get
flutter run
```

Web:

```bash
cd web
npm install
npm run dev
```
