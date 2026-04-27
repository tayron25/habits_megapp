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

  Future<void> createHabit(String name) async {
    final id = _uuid.v4();

    await _database.into(_database.habits).insert(
          HabitsCompanion.insert(
            id: id,
            name: name,
            isSynced: const Value(false),
          ),
        );

    try {
      await _supabaseClient.from('habits').insert({
        'id': id,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': false,
      });

      await (_database.update(_database.habits)..where((habit) => habit.id.equals(id)))
          .write(const HabitsCompanion(isSynced: Value(true)));
    } catch (_) {
      // Network errors are ignored so the local habit remains available offline.
    }
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
          'completed_date': completedDate.toIso8601String(),
          'is_synced': false,
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

    await (_database.delete(_database.habitLogs)
          ..where(
            (log) => log.habitId.equals(habitId) & log.completedDate.equals(completedDate),
          ))
        .go();

    try {
      await _supabaseClient
          .from('habit_logs')
          .delete()
          .eq('habit_id', habitId)
          .eq('completed_date', completedDate.toIso8601String());
    } catch (_) {
      // Network errors are ignored so the local toggle-off still succeeds.
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}