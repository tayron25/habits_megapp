import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class GymRepository {
  GymRepository({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  })  : _supabaseClient = supabaseClient,
        _database = database;

  final SupabaseClient _supabaseClient;
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  // --- 1. Crear una Plantilla con Ejercicios ---
  Future<void> saveWorkoutTemplate(String name, List<Map<String, String>> exercises) async {
    final templateId = _uuid.v4();
    final createdAt = DateTime.now();

    // 1. Guardar plantilla localmente
    await _database.into(_database.workoutTemplates).insert(
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
      await _database.into(_database.templateExercises).insert(
            TemplateExercisesCompanion.insert(
              id: exerciseId,
              templateId: templateId,
              muscleGroup: exercise['muscle_group']!,
              exerciseName: exercise['exercise_name']!,
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
        'created_at': createdAt.toIso8601String(),
        'is_synced': false,
      });
    }

    // 3. Intentar subir a Supabase
    try {
      // Subimos la plantilla
      await _supabaseClient.from('workout_templates').insert({
        'id': templateId,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'is_synced': false,
      });

      // Subimos todos los ejercicios de golpe
      if (exercisesForSupabase.isNotEmpty) {
        await _supabaseClient.from('template_exercises').insert(exercisesForSupabase);
      }

      // Si todo sale bien, marcamos como sincronizado localmente
      await (_database.update(_database.workoutTemplates)..where((t) => t.id.equals(templateId)))
          .write(const WorkoutTemplatesCompanion(isSynced: Value(true)));
          
      await (_database.update(_database.templateExercises)..where((t) => t.templateId.equals(templateId)))
          .write(const TemplateExercisesCompanion(isSynced: Value(true)));
          
    } catch (e) {
      // Si falla la red, los datos ya están seguros en Drift (SQLite)
      print('❌ Error sincronizando Plantilla de Gym: $e');
    }
  }

  // --- 2. Registrar un Entrenamiento en Vivo (Series) ---
  // (Esta función la usaremos en el próximo paso cuando armes la UI del entrenamiento)
  Future<void> saveWorkoutLog(String? templateId, List<Map<String, dynamic>> sets) async {
    final logId = _uuid.v4();
    final logDate = DateTime.now();

    // Guardar el registro base
    await _database.into(_database.workoutLogs).insert(
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
      await _database.into(_database.workoutSets).insert(
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
        'is_synced': false,
      });
    }

    try {
      await _supabaseClient.from('workout_logs').insert({
        'id': logId,
        'template_id': templateId,
        'date': logDate.toIso8601String(),
        'is_synced': false,
      });

      if (setsForSupabase.isNotEmpty) {
        await _supabaseClient.from('workout_sets').insert(setsForSupabase);
      }

      await (_database.update(_database.workoutLogs)..where((t) => t.id.equals(logId)))
          .write(const WorkoutLogsCompanion(isSynced: Value(true)));
      await (_database.update(_database.workoutSets)..where((t) => t.workoutLogId.equals(logId)))
          .write(const WorkoutSetsCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error sincronizando Entrenamiento de Gym: $e');
    }
  }

  // --- 3. Obtener el Log de hoy (o crearlo) para una plantilla ---
  Future<String> getOrCreateTodayWorkoutLog(String templateId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final existingLog = await (_database.select(_database.workoutLogs)
          ..where((l) =>
              l.templateId.equals(templateId) &
              l.date.isBetweenValues(todayStart, todayEnd)))
        .getSingleOrNull();

    if (existingLog != null) {
      return existingLog.id;
    }

    final logId = _uuid.v4();
    await _database.into(_database.workoutLogs).insert(
          WorkoutLogsCompanion.insert(
            id: logId,
            templateId: Value(templateId),
            date: Value(now),
            isSynced: const Value(false),
          ),
        );
    
    // Remoto en background
    _supabaseClient.from('workout_logs').insert({
      'id': logId,
      'template_id': templateId,
      'date': now.toIso8601String(),
      'is_synced': true,
    }).then((_) {
      (_database.update(_database.workoutLogs)..where((t) => t.id.equals(logId)))
          .write(const WorkoutLogsCompanion(isSynced: Value(true)));
    }).catchError((e) => print('Error sync workout log: $e'));

    return logId;
  }

  // --- 4. Historial y Autocompletado de Ejercicios ---
  Future<List<WorkoutSet>> getLastWorkoutSets(String exerciseName) async {
    // 1. Encontrar el logId del último entrenamiento donde se hizo este ejercicio
    final lastSet = await (_database.select(_database.workoutSets)
          ..where((s) => s.exerciseName.equals(exerciseName))
          ..orderBy([(s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();

    if (lastSet == null) return [];

    // 2. Obtener todos los sets de ese ejercicio en ese mismo logId
    return (_database.select(_database.workoutSets)
          ..where((s) =>
              s.exerciseName.equals(exerciseName) &
              s.workoutLogId.equals(lastSet.workoutLogId))
          ..orderBy([(s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Future<double> getHistoricalMaxWeight(String exerciseName) async {
    final sets = await (_database.select(_database.workoutSets)
          ..where((s) => s.exerciseName.equals(exerciseName)))
        .get();
    
    if (sets.isEmpty) return 0.0;
    
    double maxWeight = 0;
    for (var s in sets) {
      if (s.weight > maxWeight) maxWeight = s.weight;
    }
    return maxWeight;
  }

  // --- 5. CRUD de Series Individuales ---
  Future<String> addWorkoutSet({
    required String workoutLogId,
    required String exerciseName,
    required double weight,
    required int reps,
  }) async {
    final setId = _uuid.v4();
    final now = DateTime.now();

    await _database.into(_database.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: setId,
            workoutLogId: workoutLogId,
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            createdAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    // Sync
    _supabaseClient.from('workout_sets').insert({
      'id': setId,
      'workout_log_id': workoutLogId,
      'exercise_name': exerciseName,
      'weight': weight,
      'reps': reps,
      'created_at': now.toIso8601String(),
      'is_synced': true,
    }).then((_) {
      (_database.update(_database.workoutSets)..where((s) => s.id.equals(setId)))
          .write(const WorkoutSetsCompanion(isSynced: Value(true)));
    }).catchError((e) => print('Error sync set: $e'));

    return setId;
  }

  Future<void> updateWorkoutSet(String setId, double weight, int reps) async {
    await (_database.update(_database.workoutSets)..where((s) => s.id.equals(setId)))
        .write(WorkoutSetsCompanion(
          weight: Value(weight),
          reps: Value(reps),
          isSynced: const Value(false),
        ));

    // Sync
    _supabaseClient.from('workout_sets').update({
      'weight': weight,
      'reps': reps,
    }).eq('id', setId).then((_) {
      (_database.update(_database.workoutSets)..where((s) => s.id.equals(setId)))
          .write(const WorkoutSetsCompanion(isSynced: Value(true)));
    }).catchError((e) => print('Error sync update set: $e'));
  }

  Future<void> deleteWorkoutSet(String setId) async {
    await (_database.delete(_database.workoutSets)..where((s) => s.id.equals(setId))).go();
    _supabaseClient.from('workout_sets').delete().eq('id', setId).catchError((e) => print('Error sync delete set: $e'));
  }
}