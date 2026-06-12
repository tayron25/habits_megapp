import 'dart:convert';

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

  bool _isMissingShowOnHomeColumn(Object error) {
    final text = error.toString();
    return text.contains('PGRST204') && (text.contains('show_on_home') || text.contains('life_area_id'));
  }

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
      await _syncRoadmaps();
      await _syncRoadmapMilestones();
      await _syncMilestoneTasks();
      await _syncActivityEvents();

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
    final unsynced = await _database.customSelect(
      'SELECT id, content, life_area_id, status, processed_at, converted_to_type, converted_to_id, note_type, created_at FROM notes WHERE is_synced = 0',
      readsFrom: {_database.notes},
    ).get();
    for (final item in unsynced) {
      final id = item.read<String>('id');
      try {
        await _supabase.from('notes').upsert({
          'id': id,
          'content': item.read<String>('content'),
          'life_area_id': item.readNullable<String>('life_area_id'),
          'status': item.read<String>('status'),
          'processed_at': item.readNullable<DateTime>('processed_at')?.toIso8601String(),
          'converted_to_type': item.readNullable<String>('converted_to_type'),
          'converted_to_id': item.readNullable<String>('converted_to_id'),
          'note_type': item.readNullable<String>('note_type'),
          'created_at': item.read<DateTime>('created_at').toIso8601String(),
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.notes)
              ..where((t) => t.id.equals(id)))
            .write(const NotesCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Notas: $e');
      }
    }
  }

  Future<void> _syncTasks() async {
    final unsynced = await _database.customSelect(
      'SELECT id, title, description, priority, due_date, life_area_id, is_completed, status, processed_at, planned_date, completed_at, missed_at, origin_type, origin_id, created_at FROM tasks WHERE is_synced = 0',
      readsFrom: {_database.tasks},
    ).get();
    for (final item in unsynced) {
      final id = item.read<String>('id');
      try {
        await _supabase.from('tasks').upsert({
          'id': id,
          'title': item.read<String>('title'),
          'description': item.readNullable<String>('description'),
          'priority': item.read<String>('priority'),
          'due_date': item.readNullable<DateTime>('due_date')?.toIso8601String(),
          'life_area_id': item.readNullable<String>('life_area_id'),
          'is_completed': item.read<bool>('is_completed'),
          'status': item.read<String>('status'),
          'processed_at': item.readNullable<DateTime>('processed_at')?.toIso8601String(),
          'planned_date': item.readNullable<DateTime>('planned_date')?.toIso8601String(),
          'completed_at': item.readNullable<DateTime>('completed_at')?.toIso8601String(),
          'missed_at': item.readNullable<DateTime>('missed_at')?.toIso8601String(),
          'origin_type': item.readNullable<String>('origin_type'),
          'origin_id': item.readNullable<String>('origin_id'),
          'created_at': item.read<DateTime>('created_at').toIso8601String(),
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.tasks)
              ..where((t) => t.id.equals(id)))
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
          'user_id': _supabase.auth.currentUser?.id,
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
          'user_id': _supabase.auth.currentUser?.id,
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
        final extra = await _database.customSelect(
          'SELECT target_date, status, logged_at, amount, source FROM habit_logs WHERE id = ?',
          variables: [Variable.withString(item.id)],
          readsFrom: {_database.habitLogs},
        ).getSingleOrNull();
        await _supabase.from('habit_logs').upsert({
          'id': item.id,
          'habit_id': item.habitId,
          'completed_date': item.completedDate.toIso8601String(),
          'target_date': extra?.readNullable<DateTime>('target_date')?.toIso8601String(),
          'status': extra?.readNullable<String>('status') ?? 'done',
          'logged_at': extra?.readNullable<DateTime>('logged_at')?.toIso8601String(),
          'amount': extra?.readNullable<int>('amount'),
          'source': extra?.readNullable<String>('source') ?? 'manual',
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.habitLogs)
              ..where((t) => t.id.equals(item.id)))
            .write(const HabitLogsCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de Logs de Hábitos: $e');
      }
    }
  }
  Future<void> _syncRoadmaps() async {
    final unsynced = await _database.customSelect(
      'SELECT id, title, description, show_on_home, life_area_id, created_at FROM roadmaps WHERE is_synced = 0',
      readsFrom: {_database.roadmaps},
    ).get();
    for (final item in unsynced) {
      final id = item.read<String>('id');
      final payload = {
        'id': id,
        'title': item.read<String>('title'),
        'description': item.readNullable<String>('description'),
        'show_on_home': item.read<bool>('show_on_home'),
        'life_area_id': item.readNullable<String>('life_area_id'),
        'created_at': item.read<DateTime>('created_at').toIso8601String(),
        'user_id': _supabase.auth.currentUser?.id,
      };

      try {
        await _supabase.from('roadmaps').upsert(payload);
        await (_database.update(_database.roadmaps)
              ..where((t) => t.id.equals(id)))
            .write(const RoadmapsCompanion(isSynced: Value(true)));
      } catch (e) {
        if (_isMissingShowOnHomeColumn(e)) {
          try {
            final fallbackPayload = Map<String, dynamic>.from(payload)
              ..remove('show_on_home')
              ..remove('life_area_id');
            await _supabase.from('roadmaps').upsert(fallbackPayload);
            await (_database.update(_database.roadmaps)
                  ..where((t) => t.id.equals(id)))
                .write(const RoadmapsCompanion(isSynced: Value(true)));
            continue;
          } catch (fallbackError) {
            print('Error en sync de Roadmaps sin show_on_home: $fallbackError');
          }
        }
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
          'user_id': _supabase.auth.currentUser?.id,
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
        final extra = await _database.customSelect(
          'SELECT status, completed_at FROM milestone_tasks WHERE id = ?',
          variables: [Variable.withString(item.id)],
          readsFrom: {_database.milestoneTasks},
        ).getSingleOrNull();
        await _supabase.from('milestone_tasks').upsert({
          'id': item.id,
          'milestone_id': item.milestoneId,
          'title': item.title,
          'is_completed': item.isCompleted,
          'status': extra?.readNullable<String>('status') ?? (item.isCompleted ? 'done' : 'active'),
          'completed_at': extra?.readNullable<DateTime>('completed_at')?.toIso8601String(),
          'created_at': item.createdAt.toIso8601String(),
          'user_id': _supabase.auth.currentUser?.id,
        });
        await (_database.update(_database.milestoneTasks)
              ..where((t) => t.id.equals(item.id)))
            .write(const MilestoneTasksCompanion(isSynced: Value(true)));
      } catch (e) {
        print('Error en sync de MilestoneTasks: $e');
      }
    }
  }

  Future<void> _syncActivityEvents() async {
    final unsynced = await _database.customSelect(
      '''
      SELECT id, event_type, entity_type, entity_id, life_area_id, occurred_at,
             local_date, source_app, metadata_json
      FROM activity_events
      WHERE is_synced = 0
      ''',
    ).get();

    for (final item in unsynced) {
      final id = item.read<String>('id');
      try {
        await _supabase.from('activity_events').upsert({
          'id': id,
          'event_type': item.read<String>('event_type'),
          'entity_type': item.read<String>('entity_type'),
          'entity_id': item.read<String>('entity_id'),
          'life_area_id': item.readNullable<String>('life_area_id'),
          'occurred_at': item.read<DateTime>('occurred_at').toIso8601String(),
          'local_date': item.read<DateTime>('local_date').toIso8601String(),
          'source_app': item.read<String>('source_app'),
          'metadata_json': _decodeMetadata(item.readNullable<String>('metadata_json')),
          'user_id': _supabase.auth.currentUser?.id,
        });
        await _database.customUpdate(
          'UPDATE activity_events SET is_synced = ? WHERE id = ?',
          variables: [
            const Variable<bool>(true),
            Variable.withString(id),
          ],
        );
      } catch (e) {
        print('Error en sync de ActivityEvents: $e');
      }
    }
  }

  Object? _decodeMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.isEmpty) return null;
    try {
      return jsonDecode(metadataJson);
    } catch (_) {
      return {'raw': metadataJson};
    }
  }
}
