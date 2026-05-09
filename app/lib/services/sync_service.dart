import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService {
  final SupabaseClient _supabaseClient;
  final AppDatabase _database;

  SyncService({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  })  : _supabaseClient = supabaseClient,
        _database = database;

  Future<void> syncDown() async {
    try {
      print('🔄 Iniciando Sync Pull (Supabase -> Local)...');

      // NIVEL 1: Sin dependencias (o independientes de entidades principales)
      await _syncLifeAreas();

      // NIVEL 2: Dependen de Nivel 1 o son entidades padre directas
      await Future.wait([
        _syncHabits(),
        _syncTasks(),
        _syncNotes(),
        _syncRoadmaps(),
        _syncWorkoutTemplates(),
      ]);

      // NIVEL 3: Dependen de entidades de Nivel 2
      await Future.wait([
        _syncHabitLogs(),
        _syncRoadmapMilestones(),
        _syncTemplateExercises(),
        _syncWorkoutLogs(),
      ]);

      // NIVEL 4: Dependen de entidades de Nivel 3 (y WorkoutLogs)
      await Future.wait([
        _syncMilestoneTasks(),
        _syncWorkoutSets(),
      ]);

      print('✅ Sync Pull completado exitosamente.');
    } catch (e) {
      print('⚠️ Error general en Sync Pull: $e');
    }
  }

  Future<void> _syncLifeAreas() async {
    try {
      final data = await _supabaseClient.from('life_areas').select();
      final companions = data.map((row) => LifeAreasCompanion(
            id: Value(row['id'] as String),
            name: Value(row['name'] as String),
            icon: Value(row['icon'] as String?),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.lifeAreas, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: life_areas');
    } catch (e) {
      print('❌ Error en Sync Pull de life_areas: $e');
    }
  }

  Future<void> _syncNotes() async {
    try {
      final data = await _supabaseClient.from('notes').select();
      final companions = data.map((row) => NotesCompanion(
            id: Value(row['id'] as String),
            content: Value(row['content'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.notes, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: notes');
    } catch (e) {
      print('❌ Error en Sync Pull de notes: $e');
    }
  }

  Future<void> _syncTasks() async {
    try {
      final data = await _supabaseClient.from('tasks').select();
      final companions = data.map((row) => TasksCompanion(
            id: Value(row['id'] as String),
            title: Value(row['title'] as String),
            description: Value(row['description'] as String?),
            priority: Value(row['priority'] as String? ?? 'Media'),
            dueDate: row['due_date'] != null ? Value(_parseSupabaseDate(row['due_date'] as String)) : const Value.absent(),
            lifeAreaId: Value(row['life_area_id'] as String?),
            isCompleted: Value(row['is_completed'] as bool? ?? false),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.tasks, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: tasks');
    } catch (e) {
      print('❌ Error en Sync Pull de tasks: $e');
    }
  }

  Future<void> _syncHabits() async {
    try {
      final data = await _supabaseClient.from('habits').select();
      final companions = data.map((row) => HabitsCompanion(
            id: Value(row['id'] as String),
            name: Value(row['name'] as String),
            startDate: Value(_parseSupabaseDate(row['start_date'] as String)),
            endDate: row['end_date'] != null ? Value(_parseSupabaseDate(row['end_date'] as String)) : const Value.absent(),
            repeatMode: Value(row['repeat_mode'] as String? ?? 'daily'),
            specificDays: Value(row['specific_days'] as String?),
            goalAmount: Value(row['goal_amount'] as int? ?? 1),
            goalPeriod: Value(row['goal_period'] as String? ?? 'day'),
            timeOfDay: Value(row['time_of_day'] as String?),
            lifeAreaId: Value(row['life_area_id'] as String?),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.habits, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: habits');
    } catch (e) {
      print('❌ Error en Sync Pull de habits: $e');
    }
  }

  Future<void> _syncHabitLogs() async {
    try {
      final data = await _supabaseClient.from('habit_logs').select();
      final companions = data.map((row) => HabitLogsCompanion(
            id: Value(row['id'] as String),
            habitId: Value(row['habit_id'] as String),
            completedDate: Value(_parseSupabaseDate(row['completed_date'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.habitLogs, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: habit_logs');
    } catch (e) {
      print('❌ Error en Sync Pull de habit_logs: $e');
    }
  }

  Future<void> _syncRoadmaps() async {
    try {
      final data = await _supabaseClient.from('roadmaps').select();
      final companions = data.map((row) => RoadmapsCompanion(
            id: Value(row['id'] as String),
            title: Value(row['title'] as String),
            description: Value(row['description'] as String?),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.roadmaps, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: roadmaps');
    } catch (e) {
      print('❌ Error en Sync Pull de roadmaps: $e');
    }
  }

  Future<void> _syncRoadmapMilestones() async {
    try {
      final data = await _supabaseClient.from('roadmap_milestones').select();
      final companions = data.map((row) => RoadmapMilestonesCompanion(
            id: Value(row['id'] as String),
            roadmapId: Value(row['roadmap_id'] as String),
            title: Value(row['title'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.roadmapMilestones, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: roadmap_milestones');
    } catch (e) {
      print('❌ Error en Sync Pull de roadmap_milestones: $e');
    }
  }

  Future<void> _syncMilestoneTasks() async {
    try {
      final data = await _supabaseClient.from('milestone_tasks').select();
      final companions = data.map((row) => MilestoneTasksCompanion(
            id: Value(row['id'] as String),
            milestoneId: Value(row['milestone_id'] as String),
            title: Value(row['title'] as String),
            isCompleted: Value(row['is_completed'] as bool? ?? false),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.milestoneTasks, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: milestone_tasks');
    } catch (e) {
      print('❌ Error en Sync Pull de milestone_tasks: $e');
    }
  }

  Future<void> _syncWorkoutTemplates() async {
    try {
      final data = await _supabaseClient.from('workout_templates').select();
      final companions = data.map((row) => WorkoutTemplatesCompanion(
            id: Value(row['id'] as String),
            name: Value(row['name'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.workoutTemplates, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: workout_templates');
    } catch (e) {
      print('❌ Error en Sync Pull de workout_templates: $e');
    }
  }

  Future<void> _syncTemplateExercises() async {
    try {
      final data = await _supabaseClient.from('template_exercises').select();
      final companions = data.map((row) => TemplateExercisesCompanion(
            id: Value(row['id'] as String),
            templateId: Value(row['template_id'] as String),
            muscleGroup: Value(row['muscle_group'] as String),
            exerciseName: Value(row['exercise_name'] as String),
            supersetId: Value(row['superset_id'] as String?),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.templateExercises, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: template_exercises');
    } catch (e) {
      print('❌ Error en Sync Pull de template_exercises: $e');
    }
  }

  Future<void> _syncWorkoutLogs() async {
    try {
      final data = await _supabaseClient.from('workout_logs').select();
      final companions = data.map((row) => WorkoutLogsCompanion(
            id: Value(row['id'] as String),
            templateId: Value(row['template_id'] as String?),
            date: Value(DateTime.parse(row['date'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.workoutLogs, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: workout_logs');
    } catch (e) {
      print('❌ Error en Sync Pull de workout_logs: $e');
    }
  }

  Future<void> _syncWorkoutSets() async {
    try {
      final data = await _supabaseClient.from('workout_sets').select();
      final companions = data.map((row) => WorkoutSetsCompanion(
            id: Value(row['id'] as String),
            workoutLogId: Value(row['workout_log_id'] as String),
            exerciseName: Value(row['exercise_name'] as String),
            weight: Value((row['weight'] as num).toDouble()),
            reps: Value(row['reps'] as int),
            createdAt: row['created_at'] != null ? Value(DateTime.parse(row['created_at'] as String)) : const Value.absent(),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.workoutSets, companions, mode: InsertMode.insertOrReplace);
      });
      print('✅ Sync OK: workout_sets');
    } catch (e) {
      print('❌ Error en Sync Pull de workout_sets: $e');
    }
  }

  /// Repara fechas que fueron guardadas ingenuamente sin zona horaria
  /// Si detecta que es UTC puro a las 00:00:00, lo asume como un local date erróneo.
  DateTime _parseSupabaseDate(String dateStr) {
    final parsed = DateTime.parse(dateStr);
    if (parsed.isUtc && parsed.hour == 0 && parsed.minute == 0 && parsed.second == 0) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return parsed;
  }
}
