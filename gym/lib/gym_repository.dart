import 'package:gym/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';

class GymRepository {
  GymRepository({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  }) : _supabaseClient = supabaseClient,
       _database = database;

  final SupabaseClient _supabaseClient;
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  // --- 1. Crear una Plantilla con Ejercicios ---
  Future<void> saveWorkoutTemplate(
    String name,
    List<Map<String, dynamic>> exercises,
  ) async {
    final templateId = _uuid.v4();
    final createdAt = DateTime.now();

    // 1. Guardar plantilla localmente
    await _database
        .into(_database.workoutTemplates)
        .insert(
          WorkoutTemplatesCompanion.insert(
            id: templateId,
            name: name,
            createdAt: Value(createdAt),
            isSynced: const Value(false),
          ),
        );

    // 2. Guardar ejercicios de la plantilla localmente
    final List<Map<String, dynamic>> exercisesForSupabase = [];

    for (final exercise in exercises) {
      final exerciseId = _uuid.v4();
      await _database
          .into(_database.templateExercises)
          .insert(
            TemplateExercisesCompanion.insert(
              id: exerciseId,
              templateId: templateId,
              muscleGroup: exercise['muscle_group']!,
              exerciseName: exercise['exercise_name']!,
              supersetId: Value(exercise['superset_id']),
              progressionRule: Value(exercise['progression_rule']),
              progressionTargetReps: Value(exercise['progression_target_reps']),
              progressionTargetWeightIncrease: Value(exercise['progression_target_weight_increase']),
              createdAt: Value(createdAt),
              isSynced: const Value(false),
            ),
          );

      // Preparamos los datos para enviar a la nube en bloque
      exercisesForSupabase.add({
        'id': exerciseId,
        'template_id': templateId,
        'muscle_group': exercise['muscle_group'],
        'exercise_name': exercise['exercise_name'],
        'superset_id': exercise['superset_id'],
        'progression_rule': exercise['progression_rule'],
        'progression_target_reps': exercise['progression_target_reps'],
        'progression_target_weight_increase': exercise['progression_target_weight_increase'],
        'created_at': createdAt.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });
    }

    // 3. Intentar subir a Supabase
    try {
      // Subimos la plantilla
      await _supabaseClient.from('workout_templates').insert({
        'id': templateId,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });

      // Subimos todos los ejercicios de golpe
      if (exercisesForSupabase.isNotEmpty) {
        await _supabaseClient
            .from('template_exercises')
            .insert(exercisesForSupabase);
      }

      // Si todo sale bien, marcamos como sincronizado localmente
      await (_database.update(_database.workoutTemplates)
            ..where((t) => t.id.equals(templateId)))
          .write(const WorkoutTemplatesCompanion(isSynced: Value(true)));

      await (_database.update(_database.templateExercises)
            ..where((t) => t.templateId.equals(templateId)))
          .write(const TemplateExercisesCompanion(isSynced: Value(true)));
    } catch (e) {
      // Si falla la red, los datos ya están seguros en Drift (SQLite)
      print('❌ Error sincronizando Plantilla de Gym: $e');
    }
  }

  Future<void> updateWorkoutTemplate(
    String templateId,
    String name,
    List<Map<String, dynamic>> exercises,
  ) async {
    final createdAt = DateTime.now();
    final existingExercises = await (_database.select(_database.templateExercises)
          ..where((t) => t.templateId.equals(templateId)))
        .get();

    await (_database.update(_database.workoutTemplates)
          ..where((t) => t.id.equals(templateId)))
        .write(
          WorkoutTemplatesCompanion(
            name: Value(name),
            isSynced: const Value(false),
          ),
        );

    for (final exercise in existingExercises) {
      await _database.into(_database.pendingSyncActions).insert(
            PendingSyncActionsCompanion.insert(
              localTable: 'template_exercises',
              itemId: exercise.id,
              action: 'DELETE',
            ),
          );
    }

    await (_database.delete(_database.templateExercises)
          ..where((t) => t.templateId.equals(templateId)))
        .go();

    final exercisesForSupabase = <Map<String, dynamic>>[];
    for (final exercise in exercises) {
      final exerciseId = _uuid.v4();
      await _database.into(_database.templateExercises).insert(
            TemplateExercisesCompanion.insert(
              id: exerciseId,
              templateId: templateId,
              muscleGroup: exercise['muscle_group']!,
              exerciseName: exercise['exercise_name']!,
              supersetId: Value(exercise['superset_id']),
              progressionRule: Value(exercise['progression_rule']),
              progressionTargetReps: Value(exercise['progression_target_reps']),
              progressionTargetWeightIncrease: Value(exercise['progression_target_weight_increase']),
              createdAt: Value(createdAt),
              isSynced: const Value(false),
            ),
          );

      exercisesForSupabase.add({
        'id': exerciseId,
        'template_id': templateId,
        'muscle_group': exercise['muscle_group'],
        'exercise_name': exercise['exercise_name'],
        'superset_id': exercise['superset_id'],
        'progression_rule': exercise['progression_rule'],
        'progression_target_reps': exercise['progression_target_reps'],
        'progression_target_weight_increase': exercise['progression_target_weight_increase'],
        'created_at': createdAt.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });
    }

    try {
      await _supabaseClient.from('workout_templates').update({
        'name': name,
        'is_synced': true,
      }).eq('id', templateId);

      for (final exercise in existingExercises) {
        await _supabaseClient.from('template_exercises').delete().eq('id', exercise.id);
      }

      if (exercisesForSupabase.isNotEmpty) {
        await _supabaseClient.from('template_exercises').insert(exercisesForSupabase);
      }

      final existingExerciseIds = existingExercises.map((e) => e.id).toList();
      if (existingExerciseIds.isNotEmpty) {
        await (_database.delete(_database.pendingSyncActions)
              ..where((t) => t.localTable.equals('template_exercises') & t.itemId.isIn(existingExerciseIds)))
            .go();
      }
      await (_database.update(_database.workoutTemplates)
            ..where((t) => t.id.equals(templateId)))
          .write(const WorkoutTemplatesCompanion(isSynced: Value(true)));
      await (_database.update(_database.templateExercises)
            ..where((t) => t.templateId.equals(templateId)))
          .write(const TemplateExercisesCompanion(isSynced: Value(true)));
    } catch (e) {
      print('Error sincronizando actualizacion de rutina: $e');
    }
  }

  Future<void> deleteWorkoutTemplate(String templateId) async {
    final exerciseIds = await (_database.select(_database.templateExercises)
          ..where((t) => t.templateId.equals(templateId)))
        .map((exercise) => exercise.id)
        .get();

    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'workout_templates',
            itemId: templateId,
            action: 'DELETE',
          ),
        );

    await (_database.delete(_database.templateExercises)
          ..where((t) => t.templateId.equals(templateId)))
        .go();
    await (_database.delete(_database.plannedWorkouts)
          ..where((t) => t.templateId.equals(templateId)))
        .go();
    await (_database.delete(_database.workoutTemplates)
          ..where((t) => t.id.equals(templateId)))
        .go();

    try {
      await _supabaseClient.from('workout_templates').delete().eq('id', templateId);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('workout_templates') & t.itemId.equals(templateId)))
          .go();
      if (exerciseIds.isNotEmpty) {
        await (_database.delete(_database.pendingSyncActions)
              ..where((t) => t.localTable.equals('template_exercises') & t.itemId.isIn(exerciseIds)))
            .go();
      }
    } catch (e) {
      print('Rutina borrada localmente. Pendiente de sync.');
    }
  }

  // --- 2. Registrar un Entrenamiento en Vivo (Series) ---
  // (Esta función la usaremos en el próximo paso cuando armes la UI del entrenamiento)
  Future<void> saveWorkoutLog(
    String? templateId,
    List<Map<String, dynamic>> sets,
  ) async {
    if (sets.isEmpty) return;

    final logId = _uuid.v4();
    final logDate = DateTime.now();

    // Guardar el registro base
    await _database
        .into(_database.workoutLogs)
        .insert(
          WorkoutLogsCompanion.insert(
            id: logId,
            templateId: Value(templateId),
            date: Value(logDate),
            isSynced: const Value(false),
          ),
        );

    // Guardar series locales y preparar para Supabase
    final List<Map<String, dynamic>> setsForSupabase = [];
    for (final s in sets) {
      final setId = _uuid.v4();
      await _database
          .into(_database.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              id: setId,
              workoutLogId: logId,
              exerciseName: s['exercise_name'],
              weight: s['weight'],
              reps: s['reps'],
              createdAt: Value(logDate),
              isSynced: const Value(false),
            ),
          );

      setsForSupabase.add({
        'id': setId,
        'workout_log_id': logId,
        'exercise_name': s['exercise_name'],
        'weight': s['weight'],
        'reps': s['reps'],
        'created_at': logDate.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });
    }

    try {
      await _supabaseClient.from('workout_logs').insert({
        'id': logId,
        'template_id': templateId,
        'date': logDate.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });

      if (setsForSupabase.isNotEmpty) {
        await _supabaseClient.from('workout_sets').insert(setsForSupabase);
      }

      await (_database.update(_database.workoutLogs)
            ..where((t) => t.id.equals(logId)))
          .write(const WorkoutLogsCompanion(isSynced: Value(true)));
      await (_database.update(_database.workoutSets)
            ..where((t) => t.workoutLogId.equals(logId)))
          .write(const WorkoutSetsCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error sincronizando Entrenamiento de Gym: $e');
    }
  }

  // --- 3. Obtener el Log de hoy (o crearlo) para una plantilla ---
  Future<WorkoutLog?> getTodayWorkoutLogForTemplate(String templateId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return (_database.select(_database.workoutLogs)..where(
          (l) =>
              l.templateId.equals(templateId) &
              l.date.isBetweenValues(todayStart, todayEnd),
        )..limit(1))
        .getSingleOrNull();
  }

  Future<String> getOrCreateTodayWorkoutLog(String templateId) async {
    final now = DateTime.now();
    final existingLog = await getTodayWorkoutLogForTemplate(templateId);

    if (existingLog != null) {
      return existingLog.id;
    }

    final logId = _uuid.v4();
    await _database
        .into(_database.workoutLogs)
        .insert(
          WorkoutLogsCompanion.insert(
            id: logId,
            templateId: Value(templateId),
            date: Value(now),
            isSynced: const Value(false),
          ),
        );

    // Remoto en background
    _supabaseClient
        .from('workout_logs')
        .insert({
          'id': logId,
          'template_id': templateId,
          'date': now.toIso8601String(),
          'is_synced': true,
          'user_id': _supabaseClient.auth.currentUser?.id,
        })
        .then((_) {
          (_database.update(_database.workoutLogs)
                ..where((t) => t.id.equals(logId)))
              .write(const WorkoutLogsCompanion(isSynced: Value(true)));
        })
        .catchError((e) {
          print('Error sync workout log: $e');
          return null;
        });

    return logId;
  }

  Stream<List<WorkoutSet>> watchTodaySets(String templateId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Usamos un stream que emite el log de hoy
    return (_database.select(_database.workoutLogs)..where(
          (l) =>
              l.templateId.equals(templateId) &
              l.date.isBetweenValues(todayStart, todayEnd),
        )..limit(1))
        .watchSingleOrNull()
        .switchMap((log) {
          if (log == null) return Stream.value(<WorkoutSet>[]);
          return (_database.select(
            _database.workoutSets,
          )..where((s) => s.workoutLogId.equals(log.id))).watch();
        });
  }

  Future<Map<String, List<String>>> getExerciseCatalog() async {
    final catalog = <String, Set<String>>{};

    final templates = await _database.select(_database.templateExercises).get();
    for (var t in templates) {
      catalog.putIfAbsent(t.muscleGroup, () => {}).add(t.exerciseName);
    }

    // Pre-poblar algunos por defecto si está vacío
    if (catalog.isEmpty) {
      catalog['Pecho'] = {'Press de Banca', 'Aperturas', 'Flexiones'};
      catalog['Espalda'] = {'Dominadas', 'Remo con Barra', 'Jalón al Pecho'};
      catalog['Piernas'] = {
        'Sentadillas',
        'Prensa',
        'Peso Muerto Rumano',
        'Extensiones',
      };
      catalog['Brazos'] = {'Curl de Bíceps', 'Press Francés', 'Curl Martillo'};
      catalog['Hombros'] = {
        'Press Militar',
        'Elevaciones Laterales',
        'Pájaros',
      };
    }

    return catalog.map((key, value) => MapEntry(key, value.toList()..sort()));
  }

  Future<List<WorkoutSet>> getSetsForLogAndExercise(
    String workoutLogId,
    String exerciseName,
  ) async {
    return (_database.select(_database.workoutSets)
          ..where(
            (s) =>
                s.workoutLogId.equals(workoutLogId) &
                s.exerciseName.equals(exerciseName),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  // --- 4. Historial y Autocompletado de Ejercicios ---
  Future<List<WorkoutSet>> getLastWorkoutSets(String exerciseName, {String? excludeLogId}) async {
    // 1. Encontrar el logId del último entrenamiento donde se hizo este ejercicio
    var lastSetQuery = _database.select(_database.workoutSets)
      ..where((s) => s.exerciseName.equals(exerciseName));
      
    if (excludeLogId != null) {
      lastSetQuery.where((s) => s.workoutLogId.isNotValue(excludeLogId));
    }

    final lastSet = await (lastSetQuery
      ..orderBy([
        (s) => OrderingTerm(
          expression: s.createdAt,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(1))
    .getSingleOrNull();

    if (lastSet == null) return [];

    // 2. Obtener todos los sets de ese ejercicio en ese mismo logId
    return (_database.select(_database.workoutSets)
          ..where(
            (s) =>
                s.exerciseName.equals(exerciseName) &
                s.workoutLogId.equals(lastSet.workoutLogId),
          )
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<WorkoutSet?> getSuggestedNextSet(String exerciseName, int currentSetIndex, {String? currentLogId, String? templateId}) async {
    final setsFromLastWorkout = await getLastWorkoutSets(exerciseName, excludeLogId: currentLogId);
    
    if (setsFromLastWorkout.isEmpty) return null;
    
    WorkoutSet baseSet;
    if (currentSetIndex < setsFromLastWorkout.length) {
      baseSet = setsFromLastWorkout[currentSetIndex];
    } else {
      baseSet = setsFromLastWorkout.last;
    }

    // Progression logic
    String? currentTemplateId = templateId;
    if (currentTemplateId == null && currentLogId != null) {
      final log = await (_database.select(_database.workoutLogs)..where((l) => l.id.equals(currentLogId))).getSingleOrNull();
      currentTemplateId = log?.templateId;
    }

    final exTemplateQuery = _database.select(_database.templateExercises)
      ..where((t) => t.exerciseName.equals(exerciseName));
    
    if (currentTemplateId != null) {
      exTemplateQuery.where((t) => t.templateId.equals(currentTemplateId!));
    }

    final exTemplate = await (exTemplateQuery..limit(1)).getSingleOrNull();

    final rule = exTemplate?.progressionRule;
    if (rule == 'bajo' || rule == 'alto') {
      final int targetReps = rule == 'bajo' ? 12 : 16;
      final int resetReps = rule == 'bajo' ? 8 : 12;
      final double weightInc = exTemplate?.progressionTargetWeightIncrease ?? 2.5;

      bool hitTargetOnAllSets = true;
      for (var s in setsFromLastWorkout) {
        if (s.reps < targetReps) {
          hitTargetOnAllSets = false;
          break;
        }
      }

      if (hitTargetOnAllSets) {
        return WorkoutSet(
          id: 'temp',
          workoutLogId: 'temp',
          exerciseName: exerciseName,
          weight: baseSet.weight + weightInc,
          reps: resetReps,
          createdAt: DateTime.now(),
          isSynced: false,
        );
      }
    }
    
    // Si es manual, o si no se cumplió la regla, copia el historial
    return baseSet;
  }

  Stream<WorkoutSet?> watchPersonalRecord(String exerciseName) {
    return (_database.select(_database.workoutSets)
          ..where(
            (s) =>
                s.exerciseName.equals(exerciseName) &
                s.reps.isBiggerThanValue(0),
          )
          ..orderBy([
            (s) => OrderingTerm(expression: s.weight, mode: OrderingMode.desc),
            (s) => OrderingTerm(expression: s.reps, mode: OrderingMode.desc),
            (s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<WorkoutSet?> getLastSetForExercise(String exerciseName) async {
    return (_database.select(_database.workoutSets)
          ..where((s) => s.exerciseName.equals(exerciseName))
          ..orderBy([
            (s) => OrderingTerm(
              expression: s.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<WorkoutLog?> getTodayWorkoutLog() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return (_database.select(_database.workoutLogs)..where(
          (l) => l.date.isBetweenValues(todayStart, todayEnd),
        )..limit(1))
        .getSingleOrNull();
  }

  // --- 5. CRUD de Series Individuales ---
  Future<String> addWorkoutSet({
    required String workoutLogId,
    required String exerciseName,
    required double weight,
    required int reps,
    String? note,
  }) async {
    final setId = _uuid.v4();
    final now = DateTime.now();

    await _database
        .into(_database.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            id: setId,
            workoutLogId: workoutLogId,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            note: Value(note),
            createdAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    // Sync
    _supabaseClient
        .from('workout_sets')
        .insert({
          'id': setId,
          'workout_log_id': workoutLogId,
          'exercise_name': exerciseName,
          'weight': weight,
          'reps': reps,
          'note': note,
          'created_at': now.toIso8601String(),
          'is_synced': true,
          'user_id': _supabaseClient.auth.currentUser?.id,
        })
        .then((_) {
          (_database.update(_database.workoutSets)
                ..where((s) => s.id.equals(setId)))
              .write(const WorkoutSetsCompanion(isSynced: Value(true)));
        })
        .catchError((e) {
          print('Error sync set: $e');
          return null;
        });

    await _refreshPlannedWorkoutCompletionForLog(workoutLogId);

    return setId;
  }

  Future<void> updateWorkoutSet(String setId, double weight, int reps, {String? note}) async {
    await (_database.update(
      _database.workoutSets,
    )..where((s) => s.id.equals(setId))).write(
      WorkoutSetsCompanion(
        weight: Value(weight),
        reps: Value(reps),
        note: Value(note),
        isSynced: const Value(false),
      ),
    );

    // Sync
    _supabaseClient
        .from('workout_sets')
        .update({'weight': weight, 'reps': reps, 'note': note})
        .eq('id', setId)
        .then((_) {
          (_database.update(_database.workoutSets)
                ..where((s) => s.id.equals(setId)))
              .write(const WorkoutSetsCompanion(isSynced: Value(true)));
        })
        .catchError((e) {
          print('Error sync update set: $e');
          return null;
        });
  }

  Future<void> deleteWorkoutSet(String setId) async {
    final set = await (_database.select(_database.workoutSets)
          ..where((s) => s.id.equals(setId))
          ..limit(1))
        .getSingleOrNull();
    final workoutLogId = set?.workoutLogId;

    // 1. Registrar borrado pendiente
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'workout_sets',
            itemId: setId,
            action: 'DELETE',
          ),
        );

    // 2. Borrado local
    await (_database.delete(
      _database.workoutSets,
    )..where((s) => s.id.equals(setId))).go();

    // 3. Intento inmediato
    try {
      await _supabaseClient.from('workout_sets').delete().eq('id', setId);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('workout_sets') & t.itemId.equals(setId)))
          .go();
    } catch (e) {
      print('Set borrado localmente. Pendiente de sync.');
    }

    if (workoutLogId != null) {
      await _refreshPlannedWorkoutCompletionForLog(workoutLogId);
    }
  }

  // --- 6. Planificación (Calendario) ---
  Future<void> _refreshPlannedWorkoutCompletionForLog(String workoutLogId) async {
    final log = await (_database.select(_database.workoutLogs)
          ..where((l) => l.id.equals(workoutLogId))
          ..limit(1))
        .getSingleOrNull();
    if (log?.templateId == null) return;

    final dayStart = _dateOnly(log!.date);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayPlans = await (_database.select(_database.plannedWorkouts)
          ..where(
            (p) =>
                p.templateId.equals(log.templateId!) &
                p.plannedDate.isBiggerOrEqualValue(dayStart) &
                p.plannedDate.isSmallerThanValue(dayEnd),
          ))
        .get();

    for (final plan in dayPlans) {
      final isCompleted = await _hasCompletedWorkoutForPlan(plan);
      if (plan.isCompleted == isCompleted) continue;
      await _setPlannedWorkoutCompletion(plan.id, isCompleted);
    }
  }

  Future<String> scheduleWorkout(String templateId, DateTime plannedDate) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _database.into(_database.plannedWorkouts).insert(
      PlannedWorkoutsCompanion.insert(
        id: id,
        templateId: Value(templateId),
        plannedDate: plannedDate,
        createdAt: Value(now),
        isSynced: const Value(false),
      ),
    );

    _supabaseClient.from('planned_workouts').insert({
      'id': id,
      'template_id': templateId,
      'planned_date': plannedDate.toIso8601String(),
      'is_completed': false,
      'created_at': now.toIso8601String(),
      'is_synced': true,
      'user_id': _supabaseClient.auth.currentUser?.id,
    }).then((_) {
      (_database.update(_database.plannedWorkouts)..where((t) => t.id.equals(id)))
          .write(const PlannedWorkoutsCompanion(isSynced: Value(true)));
    }).catchError((e) {
      print('Error sync schedule: $e');
      return null;
    });

    return id;
  }

  Future<void> rescheduleWorkout(String id, DateTime newDate) async {
    await (_database.update(_database.plannedWorkouts)..where((t) => t.id.equals(id))).write(
      PlannedWorkoutsCompanion(plannedDate: Value(newDate), isSynced: const Value(false)),
    );

    _supabaseClient.from('planned_workouts').update({
      'planned_date': newDate.toIso8601String()
    }).eq('id', id).then((_) {
      (_database.update(_database.plannedWorkouts)..where((t) => t.id.equals(id)))
          .write(const PlannedWorkoutsCompanion(isSynced: Value(true)));
    }).catchError((e) {
      print('Error sync reschedule: $e');
      return null;
    });
  }

  Future<void> rescheduleWorkoutChain(String id, DateTime newDate) async {
    final plan = await (_database.select(_database.plannedWorkouts)
          ..where((p) => p.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (plan == null) return;

    final currentDate = _dateOnly(plan.plannedDate);
    final targetDate = _dateOnly(newDate);
    final daysToShift = targetDate.difference(currentDate).inDays;
    if (daysToShift == 0) return;

    if (plan.isCompleted) {
      await rescheduleWorkout(id, targetDate);
      return;
    }

    final pendingPlans = await (_database.select(_database.plannedWorkouts)
          ..where(
            (p) =>
                p.isCompleted.equals(false) &
                p.plannedDate.isBiggerOrEqualValue(currentDate),
          )
          ..orderBy([(p) => OrderingTerm(expression: p.plannedDate, mode: OrderingMode.asc)]))
        .get();

    await _database.transaction(() async {
      for (final pending in pendingPlans) {
        await (_database.update(_database.plannedWorkouts)
              ..where((p) => p.id.equals(pending.id)))
            .write(
          PlannedWorkoutsCompanion(
            plannedDate: Value(_dateOnly(pending.plannedDate).add(Duration(days: daysToShift))),
            isSynced: const Value(false),
          ),
        );
      }
    });

    for (final pending in pendingPlans) {
      final shiftedDate = _dateOnly(pending.plannedDate).add(Duration(days: daysToShift));
      _syncPlannedWorkoutDate(pending.id, shiftedDate);
    }
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  void _syncPlannedWorkoutDate(String id, DateTime newDate) {
    _supabaseClient.from('planned_workouts').update({
      'planned_date': newDate.toIso8601String()
    }).eq('id', id).then((_) {
      (_database.update(_database.plannedWorkouts)..where((t) => t.id.equals(id)))
          .write(const PlannedWorkoutsCompanion(isSynced: Value(true)));
    }).catchError((e) {
      print('Error sync reschedule: $e');
      return null;
    });
  }

  Future<void> _setPlannedWorkoutCompletion(String id, bool isCompleted) async {
    await (_database.update(_database.plannedWorkouts)
          ..where((t) => t.id.equals(id)))
        .write(
      PlannedWorkoutsCompanion(
        isCompleted: Value(isCompleted),
        isSynced: const Value(false),
      ),
    );

    _supabaseClient.from('planned_workouts').update({
      'is_completed': isCompleted,
    }).eq('id', id).then((_) {
      (_database.update(_database.plannedWorkouts)
            ..where((t) => t.id.equals(id)))
          .write(const PlannedWorkoutsCompanion(isSynced: Value(true)));
    }).catchError((e) {
      print('Error sync planned workout completion: $e');
      return null;
    });
  }

  Future<void> updatePlannedWorkoutTemplate(String id, String templateId) async {
    await (_database.update(_database.plannedWorkouts)
          ..where((t) => t.id.equals(id)))
        .write(
      PlannedWorkoutsCompanion(
        templateId: Value(templateId),
        isSynced: const Value(false),
      ),
    );

    _supabaseClient.from('planned_workouts').update({
      'template_id': templateId,
    }).eq('id', id).then((_) {
      (_database.update(_database.plannedWorkouts)
            ..where((t) => t.id.equals(id)))
          .write(const PlannedWorkoutsCompanion(isSynced: Value(true)));
    }).catchError((e) {
      print('Error sync planned workout template: $e');
      return null;
    });
  }

  Future<void> deletePlannedWorkout(String id) async {
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'planned_workouts',
            itemId: id,
            action: 'DELETE',
          ),
        );

    await (_database.delete(_database.plannedExercises)
          ..where((t) => t.plannedWorkoutId.equals(id)))
        .go();
    await (_database.delete(_database.plannedWorkouts)
          ..where((t) => t.id.equals(id)))
        .go();

    try {
      await _supabaseClient.from('planned_workouts').delete().eq('id', id);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('planned_workouts') & t.itemId.equals(id)))
          .go();
    } catch (e) {
      print('Plan borrado localmente. Pendiente de sync.');
    }
  }

  Future<void> deletePlannedWorkouts(List<String> ids) async {
    for (final id in ids) {
      await deletePlannedWorkout(id);
    }
  }

  // Auto-shift: mueve hacia adelante el calendario si hay rutinas pendientes en el pasado
  Future<void> autoShiftPlannedWorkouts() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _reconcileCompletedPlannedWorkouts(upToDate: today);

    // Encontrar el plan pendiente (is_completed = false) más antiguo
    final oldestPending = await (_database.select(_database.plannedWorkouts)
          ..where((p) => p.isCompleted.equals(false))
          ..orderBy([(p) => OrderingTerm(expression: p.plannedDate, mode: OrderingMode.asc)])
          ..limit(1))
        .getSingleOrNull();

    if (oldestPending == null) return;

    final oldestDate = DateTime(
      oldestPending.plannedDate.year,
      oldestPending.plannedDate.month,
      oldestPending.plannedDate.day,
    );

    if (oldestDate.isBefore(today)) {
      final daysToShift = today.difference(oldestDate).inDays;

      // Obtener todos los planes incompletos (desde el más antiguo en adelante)
      final allPending = await (_database.select(_database.plannedWorkouts)
            ..where((p) => p.isCompleted.equals(false)))
          .get();

      for (var p in allPending) {
        final newDate = p.plannedDate.add(Duration(days: daysToShift));
        await rescheduleWorkout(p.id, newDate);
      }
      print('✅ Auto-Shift completado: Se recorrieron $daysToShift días.');
    }
  }

  Future<void> _reconcileCompletedPlannedWorkouts({required DateTime upToDate}) async {
    final upToExclusive = _dateOnly(upToDate).add(const Duration(days: 1));
    final candidates = await (_database.select(_database.plannedWorkouts)
          ..where(
            (p) =>
                p.isCompleted.equals(false) &
                p.templateId.isNotNull() &
                p.plannedDate.isSmallerThanValue(upToExclusive),
          ))
        .get();

    for (final plan in candidates) {
      if (await _hasCompletedWorkoutForPlan(plan)) {
        await _setPlannedWorkoutCompletion(plan.id, true);
      }
    }
  }

  Future<bool> _hasCompletedWorkoutForPlan(PlannedWorkout plan) async {
    final templateId = plan.templateId;
    if (templateId == null) return false;

    final dayStart = _dateOnly(plan.plannedDate);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final logs = await (_database.select(_database.workoutLogs)
          ..where(
            (l) =>
                l.templateId.equals(templateId) &
                l.date.isBiggerOrEqualValue(dayStart) &
                l.date.isSmallerThanValue(dayEnd),
          ))
        .get();

    for (final log in logs) {
      final set = await (_database.select(_database.workoutSets)
            ..where((s) => s.workoutLogId.equals(log.id))
            ..limit(1))
          .getSingleOrNull();
      if (set != null) return true;
    }

    return false;
  }

  // Generador de Patrones
  // pattern: Lista de templateIds, si es nulo representa 'Descanso'
  Future<void> generateWorkoutPattern(List<String?> pattern, int weeks) async {
    if (pattern.isEmpty) return;
    
    // Buscar la última fecha planificada
    final lastPlan = await (_database.select(_database.plannedWorkouts)
          ..orderBy([(p) => OrderingTerm(expression: p.plannedDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();

    DateTime startDate;
    if (lastPlan != null) {
      startDate = lastPlan.plannedDate.add(const Duration(days: 1));
    } else {
      startDate = DateTime.now();
    }
    
    // Normalizar startDate para eliminar hora
    startDate = DateTime(startDate.year, startDate.month, startDate.day, 8, 0, 0);

    final totalDays = weeks * 7;
    for (int i = 0; i < totalDays; i++) {
      final templateId = pattern[i % pattern.length];
      if (templateId != null) {
        final planDate = startDate.add(Duration(days: i));
        await scheduleWorkout(templateId, planDate);
      }
    }
  }

  Stream<List<PlannedWorkout>> watchPlannedWorkouts(DateTime start, DateTime end) {
    return (_database.select(_database.plannedWorkouts)
          ..where((p) => p.plannedDate.isBetweenValues(start, end))
          ..orderBy([(p) => OrderingTerm(expression: p.plannedDate, mode: OrderingMode.asc)]))
        .watch();
  }
}
