import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncRepository {
  final AppDatabase _database;
  final SupabaseClient _supabase;

  SyncRepository({
    required AppDatabase database,
    required SupabaseClient supabase,
  }) : _database = database,
       _supabase = supabase;

  /// Ejecuta la sincronización completa de todos los datos pendientes.
  Future<void> synchronizeAll() async {
    print('🔄 Iniciando sincronización completa...');
    try {
      // 1. Primero procesamos los borrados (para evitar subir algo que luego se borra)
      await _syncDeletions();

      // 2. Sincronizamos tablas base
      await _syncNotes();
      await _syncTasks();
      await _syncLifeAreas();
      await _syncHabits();
      await _syncHabitLogs();
      await _syncWorkoutTemplates();
      await _syncTemplateExercises();
      await _syncWorkoutLogs();
      await _syncWorkoutSets();
      await _syncRoadmaps();
      await _syncRoadmapMilestones();
      await _syncMilestoneTasks();

      print('✅ Sincronización finalizada con éxito.');
    } catch (e) {
      print('❌ Error general durante la sincronización: $e');
    }
  }

  Future<void> _syncDeletions() async {
    final pending = await _database.select(_database.pendingSyncActions).get();
    for (final action in pending) {
      try {
        await _supabase
            .from(action.localTable)
            .delete()
            .eq('id', action.itemId);
        // Borramos de la cola local si tuvo éxito
        await (_database.delete(
          _database.pendingSyncActions,
        )..where((t) => t.id.equals(action.id))).go();
      } catch (e) {
        print(
          '⚠️ Error sincronizando borrado en ${action.localTable} (${action.itemId}): $e',
        );
      }
    }
  }

  // --- Implementaciones Específicas ---

  Future<void> _syncNotes() async {
    final unsynced = await (_database.select(
      _database.notes,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('notes').upsert({
          'id': item.id,
          'content': item.content,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.notes)
              ..where((t) => t.id.equals(item.id)))
            .write(const NotesCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Notas: $e');
      }
    }
  }

  Future<void> _syncTasks() async {
    final unsynced = await (_database.select(
      _database.tasks,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('tasks').upsert({
          'id': item.id,
          'title': item.title,
          'description': item.description,
          'priority': item.priority,
          'due_date': item.dueDate?.toIso8601String(),
          'life_area_id': item.lifeAreaId,
          'is_completed': item.isCompleted,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.tasks)
              ..where((t) => t.id.equals(item.id)))
            .write(const TasksCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Tareas: $e');
      }
    }
  }

  Future<void> _syncLifeAreas() async {
    final unsynced = await (_database.select(
      _database.lifeAreas,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('life_areas').upsert({
          'id': item.id,
          'name': item.name,
          'icon': item.icon,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.lifeAreas)
              ..where((t) => t.id.equals(item.id)))
            .write(const LifeAreasCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Áreas de Vida: $e');
      }
    }
  }

  Future<void> _syncHabits() async {
    final unsynced = await (_database.select(
      _database.habits,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('habits').upsert({
          'id': item.id,
          'name': item.name,
          'start_date': item.startDate.toIso8601String(),
          'end_date': item.endDate?.toIso8601String(),
          'repeat_mode': item.repeatMode,
          'specific_days': item.specificDays,
          'goal_amount': item.goalAmount,
          'goal_period': item.goalPeriod,
          'time_of_day': item.timeOfDay,
          'life_area_id': item.lifeAreaId,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.habits)
              ..where((t) => t.id.equals(item.id)))
            .write(const HabitsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Hábitos: $e');
      }
    }
  }

  Future<void> _syncHabitLogs() async {
    final unsynced = await (_database.select(
      _database.habitLogs,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('habit_logs').upsert({
          'id': item.id,
          'habit_id': item.habitId,
          'completed_date': item.completedDate.toIso8601String(),
        });
        await (_database.update(_database.habitLogs)
              ..where((t) => t.id.equals(item.id)))
            .write(const HabitLogsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Logs de Hábitos: $e');
      }
    }
  }

  Future<void> _syncWorkoutTemplates() async {
    final unsynced = await (_database.select(
      _database.workoutTemplates,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('workout_templates').upsert({
          'id': item.id,
          'name': item.name,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.workoutTemplates)
              ..where((t) => t.id.equals(item.id)))
            .write(const WorkoutTemplatesCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de WorkoutTemplates: $e');
      }
    }
  }

  Future<void> _syncTemplateExercises() async {
    final unsynced = await (_database.select(
      _database.templateExercises,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('template_exercises').upsert({
          'id': item.id,
          'template_id': item.templateId,
          'muscle_group': item.muscleGroup,
          'exercise_name': item.exerciseName,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.templateExercises)
              ..where((t) => t.templateId.equals(item.templateId)))
            .write(const TemplateExercisesCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de TemplateExercises: $e');
      }
    }
  }

  Future<void> _syncWorkoutLogs() async {
    final unsynced = await (_database.select(
      _database.workoutLogs,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('workout_logs').upsert({
          'id': item.id,
          'template_id': item.templateId,
          'date': item.date.toIso8601String(),
        });
        await (_database.update(_database.workoutLogs)
              ..where((t) => t.id.equals(item.id)))
            .write(const WorkoutLogsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de WorkoutLogs: $e');
      }
    }
  }

  Future<void> _syncWorkoutSets() async {
    final unsynced = await (_database.select(
      _database.workoutSets,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('workout_sets').upsert({
          'id': item.id,
          'workout_log_id': item.workoutLogId,
          'exercise_name': item.exerciseName,
          'weight': item.weight,
          'reps': item.reps,
          'created_at': item.createdAt?.toIso8601String(),
        });
        await (_database.update(_database.workoutSets)
              ..where((t) => t.id.equals(item.id)))
            .write(const WorkoutSetsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de WorkoutSets: $e');
      }
    }
  }

  Future<void> _syncRoadmaps() async {
    final unsynced = await (_database.select(
      _database.roadmaps,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('roadmaps').upsert({
          'id': item.id,
          'title': item.title,
          'description': item.description,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.roadmaps)
              ..where((t) => t.id.equals(item.id)))
            .write(const RoadmapsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Roadmaps: $e');
      }
    }
  }

  Future<void> _syncRoadmapMilestones() async {
    final unsynced = await (_database.select(
      _database.roadmapMilestones,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('roadmap_milestones').upsert({
          'id': item.id,
          'roadmap_id': item.roadmapId,
          'title': item.title,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.roadmapMilestones)
              ..where((t) => t.id.equals(item.id)))
            .write(const RoadmapMilestonesCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de RoadmapMilestones: $e');
      }
    }
  }

  Future<void> _syncMilestoneTasks() async {
    final unsynced = await (_database.select(
      _database.milestoneTasks,
    )..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('milestone_tasks').upsert({
          'id': item.id,
          'milestone_id': item.milestoneId,
          'title': item.title,
          'is_completed': item.isCompleted,
          'created_at': item.createdAt.toIso8601String(),
        });
        await (_database.update(_database.milestoneTasks)
              ..where((t) => t.id.equals(item.id)))
            .write(const MilestoneTasksCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de MilestoneTasks: $e');
      }
    }
  }
}
