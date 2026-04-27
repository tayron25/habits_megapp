# Life OS

Una aplicación móvil integral de productividad personal orientada a registrar y analizar datos del día a día. El objetivo principal no es solo registrar la información, sino construir un motor analítico (con gráficos e historiales) para medir el progreso y el balance de vida.

## 🛠 Stack Tecnológico y Arquitectura

- **Frontend / UI:** Flutter (Multiplataforma).
- **Gestor de Estado:** Riverpod con generación de código (`riverpod_annotation`, `@riverpod`).
- **Base de Datos Local (Fuente de Verdad):** Drift (SQLite).
- **Base de Datos Remota (Sincronización en 2do plano):** Supabase (PostgreSQL).

**Arquitectura Offline-First:** 
La UI lee de la base de datos local usando Streams (`ref.watch`). Al crear/editar un elemento, se inserta primero en SQLite localmente y luego se intenta subir a Supabase. Todos los modelos tienen un campo `isSynced` (booleano) y un `id` generado localmente con el paquete `uuid`.

## ⚠️ Reglas Críticas de Desarrollo

Debido a conflictos técnicos entre `drift_dev` y `riverpod_generator`, al modificar este proyecto se deben seguir estrictamente estas directrices:

1. **Importaciones Absolutas:** Usar SIEMPRE importaciones absolutas (`import 'package:app/archivo.dart';`). NUNCA usar importaciones relativas entre archivos que usan autogeneración (ej. `import '../archivo.dart'`).
2. **Typedefs para Streams de Drift en Riverpod:** Al crear `Notifiers` que devuelven un `Stream` de una lista de Drift, NUNCA uses tipos genéricos anidados profundamente en el `build()`.
    - ❌ *Incorrecto:* `Stream<List<Task>> build()`
    - ✅ *Correcto:* `typedef TasksList = List<Task>;` y luego `Stream<TasksList> build()`.
3. **Nombre de Providers Generados:** Al usar `@riverpod class TareasNotifier extends _$TareasNotifier`, el provider generado automáticamente pierde la palabra "Notifier". Para leerlo desde la UI se debe usar su nombre convertido a minúsculas, por ejemplo: `ref.watch(tareasProvider)`.

---

## 🏗️ Estado Actual del Desarrollo

El esquema actual de base de datos local (Drift) está en la **versión 4 (v4)** con 8 tablas funcionando en producción:

- **Módulo 1: Notas (Captura rápida):** Tabla `Notes` (`id`, `content`, `createdAt`, `isSynced`).
- **Módulo 2: Hábitos:** Tablas `Habits` (`id`, `name`, `createdAt`, `isSynced`) y `HabitLogs` (`id`, `habitId`, `completedDate`, `isSynced`).
- **Módulo 3: Gimnasio (Relacional Complejo):** Tablas `WorkoutTemplates` (plantillas), `TemplateExercises` (ejercicios de la plantilla), `WorkoutLogs` (registro de un día), y `WorkoutSets` (series con peso y repeticiones).
- **Módulo 4: Tareas (To-Do List):** Tabla `Tasks` (`id`, `title`, `description`, `priority`, `dueDate`, `isCompleted`, `createdAt`, `isSynced`).

La pantalla principal (`main.dart` - Pantalla Hoy) está dividida en 4 secciones scrollables que muestran Hábitos en carrusel, rutinas de Gimnasio, tareas pendientes y Notas, junto a un FloatingActionButton para agregar registros rápidamente.

---

## 🎯 Módulos Principales (MVP)

### 1. Hábitos (Habit Tracker)
Sistema para construir consistencia en el día a día.
- Frecuencia personalizable (diaria o días específicos).
- Categorización por Áreas de Vida (Salud, Estudio, Idiomas, etc.).
- Validación mediante check de completado diario.

### 2. Gimnasio (Workout Tracker)
Registro detallado del entrenamiento de fuerza.
- **Sistema de Plantillas:** Crear rutinas predefinidas instanciables.
- **Estructura Jerárquica:** Entrenamiento (Día) -> Grupos Musculares -> Ejercicios.
- Registro en vivo de Peso y Repeticiones por cada serie.

### 3. Tareas Únicas (To-Do List)
Gestor de acciones puntuales (ej. pago de cuotas, arreglos).
- Prioridades (Alta, Media, Baja) y fecha de vencimiento.
- Sub-tareas (Checklist interno).
- Cuenta regresiva y notificaciones.

### 4. Notas (Quick Captures)
Espacio de "fricción cero" para vaciar la mente.
- Soporte básico de Markdown.
- Sistema de etiquetas (hashtags) automático.
- Time-stamping automático e invisible.

### 5. Roadmaps (Metas a Largo Plazo)
Gestor de proyectos personales o metas macro.
- División por Hitos (Milestones) secuenciales.
- Objetivos específicos (Checklists) dentro de cada hito.
- Progreso porcentual global dinámico.

---

## 📊 Módulo Analítico (El Core - Próximos Pasos)

Toda la data generada alimentará este módulo mediante cruces de información:
- Gráficos históricos de cumplimiento de hábitos.
- Progresión de cargas en gimnasio a lo largo del tiempo.
- Distribución de tiempo/esfuerzo en Áreas de Vida (cruzando Hábitos, Tareas y Roadmaps).
- Análisis de horarios de máxima productividad usando metadata de Notas y Tareas.
