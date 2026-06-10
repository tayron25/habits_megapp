import 'package:gym/local_database.dart';
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

  Future<void> synchronizeAll() async {
    print('🔄 Iniciando sincronización completa del Gimnasio...');
    try {
      await _syncDeletions();
      await _syncWorkoutTemplates();
      await _syncTemplateExercises();
      await _syncWorkoutLogs();
      await _syncWorkoutSets();
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
          'is_synced': true,
          'user_id': _supabase.auth.currentUser?.id,
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
          'superset_id': item.supersetId,
          'created_at': item.createdAt.toIso8601String(),
          'is_synced': true,
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.templateExercises)
              ..where((t) => t.id.equals(item.id)))
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
          'is_synced': true,
          'user_id': _supabase.auth.currentUser?.id,
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
          'created_at': item.createdAt.toIso8601String(),
          'is_synced': true,
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.workoutSets)
              ..where((t) => t.id.equals(item.id)))
            .write(const WorkoutSetsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de WorkoutSets: $e');
      }
    }
  }

  Future<void> syncDown() async {
    print('🔄 Iniciando Sync Pull (Supabase -> Local)...');
    try {
      await Future.wait([
        _pullWorkoutTemplates(),
      ]);
      await Future.wait([
        _pullTemplateExercises(),
        _pullWorkoutLogs(),
      ]);
      await Future.wait([
        _pullWorkoutSets(),
      ]);
      print('✅ Sync Pull completado exitosamente.');
    } catch (e) {
      print('⚠️ Error general en Sync Pull: $e');
    }
  }

  Future<void> _pullWorkoutTemplates() async {
    try {
      final data = await _supabase.from('workout_templates').select();
      final companions = data.map((row) => WorkoutTemplatesCompanion(
            id: Value(row['id'] as String),
            name: Value(row['name'] as String),
            createdAt: Value(DateTime.parse(row['created_at'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.workoutTemplates, companions, mode: InsertMode.insertOrReplace);
      });
    } catch (e) {
      print('❌ Error en Sync Pull de workout_templates: $e');
    }
  }

  Future<void> _pullTemplateExercises() async {
    try {
      final data = await _supabase.from('template_exercises').select();
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
    } catch (e) {
      print('❌ Error en Sync Pull de template_exercises: $e');
    }
  }

  Future<void> _pullWorkoutLogs() async {
    try {
      final data = await _supabase.from('workout_logs').select();
      final companions = data.map((row) => WorkoutLogsCompanion(
            id: Value(row['id'] as String),
            templateId: Value(row['template_id'] as String?),
            date: Value(DateTime.parse(row['date'] as String)),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.workoutLogs, companions, mode: InsertMode.insertOrReplace);
      });
    } catch (e) {
      print('❌ Error en Sync Pull de workout_logs: $e');
    }
  }

  Future<void> _pullWorkoutSets() async {
    try {
      final data = await _supabase.from('workout_sets').select();
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
    } catch (e) {
      print('❌ Error en Sync Pull de workout_sets: $e');
    }
  }
}
