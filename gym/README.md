# Gym Tracker

Aplicación independiente para el registro avanzado de entrenamientos de fuerza, extraída del ecosistema Life OS.
Comparte el backend remoto (Supabase) con la aplicación principal, permitiendo futuras integraciones y cruce de datos para analíticas.

## 🏋️ Funcionalidades Principales

- **Gestión de Plantillas (Rutinas):** Crea y edita plantillas de entrenamiento organizadas por grupos musculares.
- **Registro en Vivo:** Registra pesos y repeticiones durante tus sesiones de entrenamiento en tiempo real.
- **Sincronización Bidireccional:** Arquitectura Offline-First con Drift y sincronización automática hacia Supabase (`syncDown` al inicio, y Push en segundo plano).
- **Ejercicios y Superseries:** Soporte nativo para ejercicios agrupados en superseries.

## 🛠️ Tecnologías

- **Framework:** Flutter / Dart
- **Base de Datos Local:** Drift (SQLite)
- **Gestión de Estado:** Riverpod (Generación de código)
- **Backend:** Supabase (Auth & Database)

## 📦 Arquitectura de Base de Datos (Local)

El proyecto contiene un esquema especializado de base de datos solo para entidades de gimnasio:
- `WorkoutTemplates`: Plantillas de entrenamiento.
- `TemplateExercises`: Ejercicios vinculados a las plantillas.
- `WorkoutLogs`: Sesiones de entrenamiento históricas o en progreso.
- `WorkoutSets`: Series individuales (peso y repeticiones).

## 🚀 Cómo Ejecutar

1. Asegúrate de tener Flutter instalado y un dispositivo/emulador activo.
2. Descarga las dependencias: `flutter pub get`
3. Ejecuta el generador de código si modificas la base de datos o providers: `dart run build_runner build -d`
4. Ejecuta la aplicación: `flutter run`
