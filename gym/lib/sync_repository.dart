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
      await _syncPlannedWorkouts();
      await _syncPlannedExercises();
      await _syncWorkoutLogs();
      await _syncWorkoutSets();
      print('✅ Sincronización finalizada con éxito.');
    } catch (e) {
      print('❌ Error general durante la sincronización: $e');
    }
  }

  Future<void> _syncPlannedWorkouts() async {
    final unsynced = await (_database.select(_database.plannedWorkouts)
      ..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('planned_workouts').upsert({
          'id': item.id,
          'template_id': item.templateId,
          'planned_date': item.plannedDate.toIso8601String(),
          'is_completed': item.isCompleted,
          'created_at': item.createdAt.toIso8601String(),
          'is_synced': true,
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.plannedWorkouts)
              ..where((t) => t.id.equals(item.id)))
            .write(const PlannedWorkoutsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de PlannedWorkouts: $e');
      }
    }
  }

  Future<void> _syncPlannedExercises() async {
    final unsynced = await (_database.select(_database.plannedExercises)
      ..where((t) => t.isSynced.equals(false))).get();
    for (final item in unsynced) {
      try {
        await _supabase.from('planned_exercises').upsert({
          'id': item.id,
          'planned_workout_id': item.plannedWorkoutId,
          'exercise_name': item.exerciseName,
          'target_weight': item.targetWeight,
          'target_reps': item.targetReps,
          'created_at': item.createdAt.toIso8601String(),
          'is_synced': true,
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.plannedExercises)
              ..where((t) => t.id.equals(item.id)))
            .write(const PlannedExercisesCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de PlannedExercises: $e');
      }
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
          'progression_rule': item.progressionRule,
          'progression_target_reps': item.progressionTargetReps,
          'progression_target_weight_increase': item.progressionTargetWeightIncrease,
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
          'note': item.note,
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
        _syncPullTable('workout_logs', _database.workoutLogs),
        _syncPullTable('workout_sets', _database.workoutSets),
        _syncPullTable('planned_workouts', _database.plannedWorkouts),
        _syncPullTable('planned_exercises', _database.plannedExercises),
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

      final remoteIds = data.map((row) => row['id'] as String).toList();
      if (remoteIds.isEmpty) {
        await (_database.delete(_database.workoutTemplates)..where((t) => t.isSynced.equals(true))).go();
      } else {
        await (_database.delete(_database.workoutTemplates)..where((t) => t.id.isNotIn(remoteIds) & t.isSynced.equals(true))).go();
      }
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
            progressionRule: Value(row['progression_rule'] as String?),
            progressionTargetReps: Value(row['progression_target_reps'] as int?),
            progressionTargetWeightIncrease: Value(row['progression_target_weight_increase'] != null ? double.parse(row['progression_target_weight_increase'].toString()) : null),
            createdAt: row['created_at'] != null ? Value(DateTime.parse(row['created_at'] as String)) : const Value.absent(),
            isSynced: const Value(true),
          ));

      await _database.batch((batch) {
        batch.insertAll(_database.templateExercises, companions, mode: InsertMode.insertOrReplace);
      });

      final remoteIds = data.map((row) => row['id'] as String).toList();
      if (remoteIds.isEmpty) {
        await (_database.delete(_database.templateExercises)..where((t) => t.isSynced.equals(true))).go();
      } else {
        await (_database.delete(_database.templateExercises)..where((t) => t.id.isNotIn(remoteIds) & t.isSynced.equals(true))).go();
      }
    } catch (e) {
      print('❌ Error en Sync Pull de template_exercises: $e');
    }
  }

  Future<void> _syncPullTable(String tableName, Table table) async {
    try {
      final data = await _supabase.from(tableName).select();
      await _database.batch((batch) {
        if (table == _database.workoutLogs) {
          final companions = data.map((row) => WorkoutLogsCompanion(
            id: Value(row['id']),
            templateId: Value(row['template_id']),
            date: Value(DateTime.parse(row['date'])),
            isSynced: const Value(true),
          ));
          batch.insertAll(_database.workoutLogs, companions, mode: InsertMode.insertOrReplace);
        } else if (table == _database.workoutSets) {
          final companions = data.map((row) => WorkoutSetsCompanion(
            id: Value(row['id']),
            workoutLogId: Value(row['workout_log_id']),
            exerciseName: Value(row['exercise_name']),
            weight: Value(double.parse(row['weight'].toString())),
            reps: Value(row['reps']),
            note: Value(row['note']),
            createdAt: Value(DateTime.parse(row['created_at'])),
            isSynced: const Value(true),
          ));
          batch.insertAll(_database.workoutSets, companions, mode: InsertMode.insertOrReplace);
        } else if (table == _database.plannedWorkouts) {
          final companions = data.map((row) => PlannedWorkoutsCompanion(
            id: Value(row['id']),
            templateId: Value(row['template_id']),
            plannedDate: Value(DateTime.parse(row['planned_date'])),
            isCompleted: Value(row['is_completed']),
            createdAt: Value(DateTime.parse(row['created_at'])),
            isSynced: const Value(true),
          ));
          batch.insertAll(_database.plannedWorkouts, companions, mode: InsertMode.insertOrReplace);
        } else if (table == _database.plannedExercises) {
          final companions = data.map((row) => PlannedExercisesCompanion(
            id: Value(row['id']),
            plannedWorkoutId: Value(row['planned_workout_id']),
            exerciseName: Value(row['exercise_name']),
            targetWeight: Value(row['target_weight'] != null ? double.parse(row['target_weight'].toString()) : null),
            targetReps: Value(row['target_reps']),
            createdAt: Value(DateTime.parse(row['created_at'])),
            isSynced: const Value(true),
          ));
          batch.insertAll(_database.plannedExercises, companions, mode: InsertMode.insertOrReplace);
        }
      });

      final remoteIds = data.map((row) => row['id'] as String).toList();
      if (remoteIds.isEmpty) {
        if (table == _database.workoutLogs) {
          await (_database.delete(_database.workoutLogs)..where((t) => t.isSynced.equals(true))).go();
        } else if (table == _database.workoutSets) {
          await (_database.delete(_database.workoutSets)..where((t) => t.isSynced.equals(true))).go();
        } else if (table == _database.plannedWorkouts) {
          await (_database.delete(_database.plannedWorkouts)..where((t) => t.isSynced.equals(true))).go();
        } else if (table == _database.plannedExercises) {
          await (_database.delete(_database.plannedExercises)..where((t) => t.isSynced.equals(true))).go();
        }
      } else {
        if (table == _database.workoutLogs) {
          await (_database.delete(_database.workoutLogs)..where((t) => t.id.isNotIn(remoteIds) & t.isSynced.equals(true))).go();
        } else if (table == _database.workoutSets) {
          await (_database.delete(_database.workoutSets)..where((t) => t.id.isNotIn(remoteIds) & t.isSynced.equals(true))).go();
        } else if (table == _database.plannedWorkouts) {
          await (_database.delete(_database.plannedWorkouts)..where((t) => t.id.isNotIn(remoteIds) & t.isSynced.equals(true))).go();
        } else if (table == _database.plannedExercises) {
          await (_database.delete(_database.plannedExercises)..where((t) => t.id.isNotIn(remoteIds) & t.isSynced.equals(true))).go();
        }
      }
    } catch (e) {
      print('❌ Error en Sync Pull de $tableName: $e');
    }
  }
}
