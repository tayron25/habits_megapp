import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class HabitsRepository {
  HabitsRepository({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  })  : _supabaseClient = supabaseClient,
        _database = database;

  final SupabaseClient _supabaseClient;
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<void> createHabit({
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    required String repeatMode,
    String? specificDays,
    required int goalAmount,
    required String goalPeriod,
    String? timeOfDay,
    String? lifeAreaId,
  }) async {
    final id = _uuid.v4();

    await _database.into(_database.habits).insert(
          HabitsCompanion.insert(
            id: id,
            name: name,
            startDate: Value(startDate),
            endDate: Value(endDate),
            repeatMode: Value(repeatMode),
            specificDays: Value(specificDays),
            goalAmount: Value(goalAmount),
            goalPeriod: Value(goalPeriod),
            timeOfDay: Value(timeOfDay),
            lifeAreaId: Value(lifeAreaId),
            isSynced: const Value(false),
          ),
        );

    try {
      await _supabaseClient.from('habits').insert({
        'id': id,
        'name': name,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate?.toUtc().toIso8601String(),
        'repeat_mode': repeatMode,
        'specific_days': specificDays,
        'goal_amount': goalAmount,
        'goal_period': goalPeriod,
        'time_of_day': timeOfDay,
        'life_area_id': lifeAreaId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });

      await (_database.update(_database.habits)..where((habit) => habit.id.equals(id)))
          .write(const HabitsCompanion(isSynced: Value(true)));
    } catch (_) {
      // Network errors are ignored so the local habit remains available offline.
    }
  }

  Future<void> updateHabit(
    String id, {
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    required String repeatMode,
    String? specificDays,
    required int goalAmount,
    required String goalPeriod,
    String? timeOfDay,
    String? lifeAreaId,
  }) async {
    // Local
    await (_database.update(_database.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        name: Value(name),
        startDate: Value(startDate),
        endDate: Value(endDate),
        repeatMode: Value(repeatMode),
        specificDays: Value(specificDays),
        goalAmount: Value(goalAmount),
        goalPeriod: Value(goalPeriod),
        timeOfDay: Value(timeOfDay),
        lifeAreaId: Value(lifeAreaId),
        isSynced: const Value(false),
      ),
    );

    // Remoto
    try {
      await _supabaseClient.from('habits').update({
        'name': name,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate?.toUtc().toIso8601String(),
        'repeat_mode': repeatMode,
        'specific_days': specificDays,
        'goal_amount': goalAmount,
        'goal_period': goalPeriod,
        'time_of_day': timeOfDay,
        'life_area_id': lifeAreaId,
        'is_synced': true,
      }).eq('id', id);

      await (_database.update(_database.habits)..where((h) => h.id.equals(id)))
          .write(const HabitsCompanion(isSynced: Value(true)));
    } catch (_) {}
  }

  Future<void> toggleHabitCompletion(
    String habitId,
    DateTime date,
    bool isCompleted,
  ) async {
    final completedDate = _normalizeDate(date);

    if (isCompleted) {
      final logId = _uuid.v4();

      await _database.into(_database.habitLogs).insert(
            HabitLogsCompanion.insert(
              id: logId,
              habitId: habitId,
              completedDate: completedDate,
              isSynced: const Value(false),
            ),
          );

      try {
        await _supabaseClient.from('habit_logs').insert({
          'id': logId,
          'habit_id': habitId,
          'completed_date': completedDate.toUtc().toIso8601String(),
          'is_synced': false,
          'user_id': _supabaseClient.auth.currentUser?.id,
        });

        await (_database.update(_database.habitLogs)
              ..where(
                (log) => log.id.equals(logId),
              ))
            .write(const HabitLogsCompanion(isSynced: Value(true)));
      } catch (_) {
        // Network errors are ignored so the local completion remains available offline.
      }
      return;
    }

    // 1. Encontrar el log local para obtener su ID antes de borrarlo
    final logToDelete = await (_database.select(_database.habitLogs)
          ..where(
            (log) => log.habitId.equals(habitId) & log.completedDate.equals(completedDate),
          ))
        .getSingleOrNull();

    if (logToDelete != null) {
      // 2. Registrar el borrado pendiente
      await _database.into(_database.pendingSyncActions).insert(
            PendingSyncActionsCompanion.insert(
              localTable: 'habit_logs',
              itemId: logToDelete.id,
              action: 'DELETE',
            ),
          );

      // 3. Borrado Local
      await (_database.delete(_database.habitLogs)
            ..where((log) => log.id.equals(logToDelete.id)))
          .go();

      // 4. Intento Remoto
      try {
        await _supabaseClient.from('habit_logs').delete().eq('id', logToDelete.id);
        await (_database.delete(_database.pendingSyncActions)
              ..where((t) => t.localTable.equals('habit_logs') & t.itemId.equals(logToDelete.id)))
            .go();
      } catch (_) {
        print('Habit log borrado localmente. Pendiente de sync.');
      }
    }
  }

  Future<int> getHabitLogsCountForPeriod(String habitId, DateTime start, DateTime end) async {
    final startNormalized = _normalizeDate(start);
    final endNormalized = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final countExpression = _database.habitLogs.id.count();
    final query = _database.selectOnly(_database.habitLogs)
      ..addColumns([countExpression])
      ..where(_database.habitLogs.habitId.equals(habitId) &
          _database.habitLogs.completedDate.isBetweenValues(startNormalized, endNormalized));

    final result = await query.map((row) => row.read(countExpression)).getSingle();
    return result ?? 0;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> deleteHabit(String id) async {
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'habits',
            itemId: id,
            action: 'DELETE',
          ),
        );

    await (_database.delete(_database.habits)..where((h) => h.id.equals(id))).go();

    try {
      await _supabaseClient.from('habits').delete().eq('id', id);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('habits') & t.itemId.equals(id)))
          .go();
    } catch (_) {
    }
  }
}