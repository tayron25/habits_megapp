import 'dart:convert';

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

    await _recordActivityEvent(
      eventType: 'habit_created',
      entityType: 'habit',
      entityId: id,
      lifeAreaId: lifeAreaId,
      occurredAt: DateTime.now(),
      metadata: {
        'repeat_mode': repeatMode,
        'goal_amount': goalAmount,
        'goal_period': goalPeriod,
      },
    );
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
      final loggedAt = DateTime.now();

      await _database.into(_database.habitLogs).insert(
            HabitLogsCompanion.insert(
              id: logId,
              habitId: habitId,
              completedDate: completedDate,
              isSynced: const Value(false),
            ),
          );

      await _database.customUpdate(
        'UPDATE habit_logs SET target_date = ?, status = ?, logged_at = ?, amount = ?, source = ? WHERE id = ?',
        variables: [
          Variable<DateTime>(completedDate),
          Variable.withString('done'),
          Variable<DateTime>(loggedAt),
          const Variable<int>(1),
          Variable.withString('manual'),
          Variable.withString(logId),
        ],
        updates: {_database.habitLogs},
      );

      final habit = await (_database.select(_database.habits)..where((h) => h.id.equals(habitId))).getSingleOrNull();
      try {
        await _supabaseClient.from('habit_logs').insert({
          'id': logId,
          'habit_id': habitId,
          'completed_date': completedDate.toUtc().toIso8601String(),
          'target_date': completedDate.toUtc().toIso8601String(),
          'status': 'done',
          'logged_at': loggedAt.toUtc().toIso8601String(),
          'amount': 1,
          'source': 'manual',
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
      await _recordActivityEvent(
        eventType: 'habit_completed',
        entityType: 'habit',
        entityId: habitId,
        lifeAreaId: habit?.lifeAreaId,
        occurredAt: loggedAt,
        metadata: {'target_date': completedDate.toIso8601String(), 'amount': 1},
      );
      return;
    }

    // 1. Encontrar el log local para obtener su ID antes de borrarlo
    final logToDelete = await (_database.select(_database.habitLogs)
          ..where(
            (log) => log.habitId.equals(habitId) & log.completedDate.equals(completedDate),
          ))
        .getSingleOrNull();

    if (logToDelete != null) {
      final habit = await (_database.select(_database.habits)..where((h) => h.id.equals(habitId))).getSingleOrNull();
      await _recordActivityEvent(
        eventType: 'habit_uncompleted',
        entityType: 'habit',
        entityId: habitId,
        lifeAreaId: habit?.lifeAreaId,
        occurredAt: DateTime.now(),
        metadata: {'target_date': completedDate.toIso8601String()},
      );

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

  Future<void> _recordActivityEvent({
    required String eventType,
    required String entityType,
    required String entityId,
    String? lifeAreaId,
    required DateTime occurredAt,
    Map<String, Object?>? metadata,
  }) async {
    await _database.customInsert(
      '''
      INSERT OR REPLACE INTO activity_events (
        id, event_type, entity_type, entity_id, life_area_id,
        occurred_at, local_date, source_app, metadata_json, is_synced
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(_uuid.v4()),
        Variable.withString(eventType),
        Variable.withString(entityType),
        Variable.withString(entityId),
        Variable<String>(lifeAreaId),
        Variable<DateTime>(occurredAt),
        Variable<DateTime>(DateTime(occurredAt.year, occurredAt.month, occurredAt.day)),
        Variable.withString('life_os'),
        Variable<String>(metadata == null ? null : jsonEncode(metadata)),
        const Variable<bool>(false),
      ],
    );
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
