# Life OS

Una aplicación móvil integral de productividad personal orientada a registrar y analizar datos del día a día. El objetivo principal no es solo registrar la información, sino construir un motor analítico (con gráficos e historiales) para medir el progreso y el balance de vida.

## 🛠 Stack Tecnológico y Arquitectura

- **Frontend / UI:** Flutter (Multiplataforma).
- **Gestor de Estado:** Riverpod con generación de código (`riverpod_annotation`, `@riverpod`).
- **Base de Datos Local (Fuente de Verdad):** Drift (SQLite).
- **Base de Datos Remota (Sincronización en 2do plano):** Supabase (PostgreSQL).

**Arquitectura Offline-First:** 
La UI lee de la base de datos local usando Streams (`ref.watch`). Al crear/editar un elemento, se inserta primero en SQLite localmente y luego se intenta subir a Supabase. Todos los modelos tienen un campo `isSynced` (booleano) y un `id` generado localmente con el paquete `uuid`.

---

## ⚠️ REGLAS CRÍTICAS DE DESARROLLO (¡LEER SIEMPRE!)

> **ATENCIÓN AGENTES DE IA:** Este proyecto se desarrolla de forma intermitente y en múltiples máquinas. Para no depender de la memoria de la IA de cada sesión, **DEBES ACTUALIZAR ESTE README CADA VEZ QUE HAGAS UN CAMBIO ESTRUCTURAL O AÑADAS UN FEATURE**. Este archivo es la única fuente de verdad garantizada.

1. **Scripts de Supabase (SQL) sin restricciones:** SIEMPRE que se te pida generar código SQL para crear o modificar tablas en Supabase, **DEBES INCLUIR** los permisos para el rol anónimo y desactivar la seguridad por fila temporalmente para el MVP. Es obligatorio añadir al final de tus scripts:
   ```sql
   GRANT SELECT, INSERT, UPDATE, DELETE ON public.<nombre_tabla> TO anon;
   ALTER TABLE <nombre_tabla> DISABLE ROW LEVEL SECURITY;
   ```
2. **Importaciones Absolutas:** Usar SIEMPRE importaciones absolutas (`import 'package:app/archivo.dart';`). NUNCA usar importaciones relativas entre archivos que usan autogeneración (ej. `import '../archivo.dart'`).
3. **Typedefs para Streams de Drift en Riverpod:** Al crear `Notifiers` que devuelven un `Stream` de una lista de Drift, NUNCA uses tipos genéricos anidados profundamente en el `build()`.
    - ❌ *Incorrecto:* `Stream<List<Task>> build()`
    - ✅ *Correcto:* `typedef TasksList = List<Task>;` y luego `Stream<TasksList> build()`.
4. **Nombre de Providers Generados:** Al usar `@riverpod class TareasNotifier extends _$TareasNotifier`, el provider generado automáticamente pierde la palabra "Notifier". Para leerlo desde la UI se debe usar su nombre convertido a minúsculas: `ref.watch(tareasProvider)`.

---

## 🏗️ Estado Actual del Desarrollo

El esquema actual de base de datos local (Drift) está en la **versión 8 (v8)** con 12 tablas operativas en el ecosistema:

- **Módulo Áreas de Vida:** Tabla `LifeAreas` (`id`, `name`, `icon`, `createdAt`, `isSynced`).
- **Módulo Notas (Quick Captures):** Tabla `Notes` (`id`, `content`, `createdAt`, `isSynced`).
- **Módulo Hábitos (V3):** Tablas `Habits` (avanzada con `startDate`, `endDate`, `repeatMode`, `goalAmount`, `goalPeriod`, `timeOfDay`, `lifeAreaId`) y `HabitLogs` (registro diario).
- **Módulo Gimnasio:** Tablas `WorkoutTemplates` (plantillas), `TemplateExercises` (ejercicios), `WorkoutLogs` (sesión activa), y `WorkoutSets` (series/repeticiones).
- **Módulo Tareas (To-Do):** Tabla `Tasks` (`title`, `description`, `priority`, `dueDate`, `lifeAreaId`, `isCompleted`).
- **Módulo Roadmaps (Metas Largo Plazo):** Tablas `Roadmaps` (meta global), `RoadmapMilestones` (hitos) y `MilestoneTasks` (checklist de hitos).

La interfaz gráfica principal (`main.dart` - Pantalla Hoy) está estructurada de forma vertical, mostrando únicamente la información relevante para **el día de hoy** (ej. los hábitos se filtran reactivamente para no mostrar los que expiran o no tocan hoy). El `FloatingActionButton` centraliza la creación de cualquier entidad mediante modales (`showModalBottomSheet`).

---

## 🎯 Módulos Implementados

### 1. Hábitos Avanzados (V3)
Sistema dinámico para construir consistencia.
- Fechas de vigencia (Inicio / Fin opcional).
- Frecuencia personalizable (Diario, Mensual, Intervalos) con metas dinámicas (veces por día, semana, mes, año).
- Asociados fuertemente a las "Áreas de Vida".
- Filtrado inteligente reactivo.

### 2. Gimnasio (Workout Tracker)
Registro detallado del entrenamiento de fuerza.
- Creación de plantillas.
- Registro en vivo de Peso y Repeticiones por cada serie durante la sesión.

### 3. Tareas Únicas (To-Do List)
Gestor de acciones puntuales.
- Prioridades (Alta, Media, Baja) indicadas visualmente con colores.
- Fecha de vencimiento opcional con widget de cuenta regresiva en lenguaje natural.
- Vinculación a Áreas de Vida (categorización transversal).

### 4. Notas (Quick Captures)
Espacio de "fricción cero" para capturar pensamientos al vuelo en texto plano.

### 5. Roadmaps (Metas a Largo Plazo)
Gestor de proyectos macro.
- Permite desglosar un objetivo en múltiples "Hitos" (Milestones).
- Calcula el porcentaje de avance global en base a las tareas específicas de cada hito marcadas como completadas.

---

## 📊 Módulo Analítico (El Core - Pendiente)

Toda la data generada hasta ahora (`v8`) está preparada para alimentar el módulo de Inteligencia de Negocios Personal mediante cruces de información:
- Gráficos históricos de cumplimiento de hábitos.
- Progresión de cargas en gimnasio a lo largo del tiempo.
- Distribución de tiempo/esfuerzo en las nuevas "Áreas de Vida" (cruzando Hábitos, Tareas y Roadmaps).
- Análisis de horarios de máxima productividad usando metadata de Notas y Tareas (`createdAt`).
