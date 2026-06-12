import 'dart:convert';

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
      print('ðŸ”„ Iniciando Sync Pull (Supabase -> Local)...');

      // NIVEL 1: Sin dependencias (o independientes de entidades principales)
      await _syncLifeAreas();

      // NIVEL 2: Dependen de Nivel 1 o son entidades padre directas
      await Future.wait([
        _syncHabits(),
        _syncTasks(),
        _syncNotes(),
        _syncRoadmaps(),
      ]);

      // NIVEL 3: Dependen de entidades de Nivel 2
      await Future.wait([
        _syncHabitLogs(),
        _syncRoadmapMilestones(),
      ]);

      // NIVEL 4: Dependen de entidades de Nivel 3
      await Future.wait([
        _syncMilestoneTasks(),
        _syncActivityEvents(),
      ]);

      print('âœ… Sync Pull completado exitosamente.');
    } catch (e) {
      print('âš ï¸ Error general en Sync Pull: $e');
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
      print('âœ… Sync OK: life_areas');
    } catch (e) {
      print('âŒ Error en Sync Pull de life_areas: $e');
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
      for (final row in data) {
        final lifeAreaId = row['life_area_id'] as String?;
        final processedAt = row['processed_at'] != null ? DateTime.parse(row['processed_at'] as String) : null;
        final lifeAreaSql = lifeAreaId == null ? 'NULL' : '?';
        final processedAtSql = processedAt == null ? 'NULL' : '?';

        await _database.customUpdate(
          'UPDATE notes SET life_area_id = $lifeAreaSql, status = ?, processed_at = $processedAtSql, converted_to_type = ?, converted_to_id = ?, note_type = ? WHERE id = ?',
          variables: [
            if (lifeAreaId != null) Variable.withString(lifeAreaId),
            Variable.withString(row['status'] as String? ?? 'captured'),
            if (processedAt != null) Variable<DateTime>(processedAt),
            Variable<String>(row['converted_to_type'] as String?),
            Variable<String>(row['converted_to_id'] as String?),
            Variable<String>(row['note_type'] as String?),
            Variable.withString(row['id'] as String),
          ],
          updates: {_database.notes},
        );
      }
      print('âœ… Sync OK: notes');
    } catch (e) {
      print('âŒ Error en Sync Pull de notes: $e');
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
      for (final row in data) {
        final processedAt = row['processed_at'] != null ? DateTime.parse(row['processed_at'] as String) : null;
        final processedAtSql = processedAt == null ? 'NULL' : '?';

        await _database.customUpdate(
          'UPDATE tasks SET status = ?, processed_at = $processedAtSql, planned_date = ?, completed_at = ?, missed_at = ?, origin_type = ?, origin_id = ? WHERE id = ?',
          variables: [
            Variable.withString(row['status'] as String? ?? 'active'),
            if (processedAt != null) Variable<DateTime>(processedAt),
            Variable<DateTime>(row['planned_date'] != null ? _parseSupabaseDate(row['planned_date'] as String) : null),
            Variable<DateTime>(row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null),
            Variable<DateTime>(row['missed_at'] != null ? DateTime.parse(row['missed_at'] as String) : null),
            Variable<String>(row['origin_type'] as String?),
            Variable<String>(row['origin_id'] as String?),
            Variable.withString(row['id'] as String),
          ],
          updates: {_database.tasks},
        );
      }
      print('âœ… Sync OK: tasks');
    } catch (e) {
      print('âŒ Error en Sync Pull de tasks: $e');
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
      print('âœ… Sync OK: habits');
    } catch (e) {
      print('âŒ Error en Sync Pull de habits: $e');
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
      for (final row in data) {
        await _database.customUpdate(
          'UPDATE habit_logs SET target_date = ?, status = ?, logged_at = ?, amount = ?, source = ? WHERE id = ?',
          variables: [
            Variable<DateTime>(row['target_date'] != null ? _parseSupabaseDate(row['target_date'] as String) : null),
            Variable.withString(row['status'] as String? ?? 'done'),
            Variable<DateTime>(row['logged_at'] != null ? DateTime.parse(row['logged_at'] as String) : null),
            Variable<int>(row['amount'] as int?),
            Variable.withString(row['source'] as String? ?? 'manual'),
            Variable.withString(row['id'] as String),
          ],
          updates: {_database.habitLogs},
        );
      }
      print('Sync OK: habit_logs');
    } catch (e) {
      print('Error en Sync Pull de habit_logs: $e');
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
      for (final row in data) {
        await _database.customUpdate(
          'UPDATE roadmaps SET show_on_home = ?, life_area_id = ? WHERE id = ?',
          variables: [
            Variable<bool>(row['show_on_home'] as bool? ?? true),
            Variable<String>(row['life_area_id'] as String?),
            Variable.withString(row['id'] as String),
          ],
          updates: {_database.roadmaps},
        );
      }
      print('âœ… Sync OK: roadmaps');
    } catch (e) {
      print('âŒ Error en Sync Pull de roadmaps: $e');
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
      print('âœ… Sync OK: roadmap_milestones');
    } catch (e) {
      print('âŒ Error en Sync Pull de roadmap_milestones: $e');
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
      for (final row in data) {
        await _database.customUpdate(
          'UPDATE milestone_tasks SET status = ?, completed_at = ? WHERE id = ?',
          variables: [
            Variable.withString(row['status'] as String? ?? ((row['is_completed'] as bool? ?? false) ? 'done' : 'active')),
            Variable<DateTime>(row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null),
            Variable.withString(row['id'] as String),
          ],
          updates: {_database.milestoneTasks},
        );
      }
      print('Sync OK: milestone_tasks');
    } catch (e) {
      print('Error en Sync Pull de milestone_tasks: $e');
    }
  }

  Future<void> _syncActivityEvents() async {
    try {
      final data = await _supabaseClient.from('activity_events').select();
      for (final row in data) {
        await _database.customInsert(
          '''
          INSERT OR REPLACE INTO activity_events (
            id, event_type, entity_type, entity_id, life_area_id,
            occurred_at, local_date, source_app, metadata_json, is_synced
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            Variable.withString(row['id'] as String),
            Variable.withString(row['event_type'] as String),
            Variable.withString(row['entity_type'] as String),
            Variable.withString(row['entity_id'] as String),
            Variable<String>(row['life_area_id'] as String?),
            Variable<DateTime>(DateTime.parse(row['occurred_at'] as String)),
            Variable<DateTime>(_parseSupabaseDate(row['local_date'] as String)),
            Variable.withString(row['source_app'] as String? ?? 'life_os'),
            Variable<String>(_encodeMetadata(row['metadata_json'])),
            const Variable<bool>(true),
          ],
        );
      }
      print('Sync OK: activity_events');
    } catch (e) {
      print('Error en Sync Pull de activity_events: $e');
    }
  }


  String? _encodeMetadata(Object? metadata) {
    if (metadata == null) return null;
    if (metadata is String) return metadata;
    return jsonEncode(metadata);
  }

  /// Repara fechas que fueron guardadas ingenuamente sin zona horaria
  /// Si detecta que es UTC puro a las 00:00:00, lo asume como un local date errÃ³neo.
  DateTime _parseSupabaseDate(String dateStr) {
    final parsed = DateTime.parse(dateStr);
    if (parsed.isUtc && parsed.hour == 0 && parsed.minute == 0 && parsed.second == 0) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return parsed;
  }
}



