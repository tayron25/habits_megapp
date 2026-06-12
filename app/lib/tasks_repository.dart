import 'dart:convert';

import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TasksRepository {
  TasksRepository({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  })  : _supabaseClient = supabaseClient,
        _database = database;

  final SupabaseClient _supabaseClient;
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  // --- Crear Tarea ---
  Future<void> createTask({
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    String? lifeAreaId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // 1. Local
    await _database.into(_database.tasks).insert(
          TasksCompanion.insert(
            id: id,
            title: title,
            description: Value(description),
            priority: Value(priority),
            dueDate: Value(dueDate),
            lifeAreaId: Value(lifeAreaId),
            createdAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    // 2. Remoto
    try {
      await _supabaseClient.from('tasks').insert({
        'id': id,
        'title': title,
        'description': description,
        'priority': priority,
        'due_date': dueDate?.toIso8601String(),
        'life_area_id': lifeAreaId,
        'status': 'active',
        'processed_at': null,
        'planned_date': dueDate?.toIso8601String(),
        'completed_at': null,
        'missed_at': null,
        'origin_type': 'manual',
        'origin_id': null,
        'created_at': now.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });

      await (_database.update(_database.tasks)..where((t) => t.id.equals(id)))
          .write(const TasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync en tarea: $e');
    }

    await _database.customUpdate(
      'UPDATE tasks SET planned_date = ?, origin_type = ? WHERE id = ?',
      variables: [
        Variable<DateTime>(dueDate),
        Variable.withString('manual'),
        Variable.withString(id),
      ],
      updates: {_database.tasks},
    );
    await _recordActivityEvent(
      eventType: 'task_created',
      entityType: 'task',
      entityId: id,
      lifeAreaId: lifeAreaId,
      occurredAt: now,
      metadata: {'priority': priority, 'has_due_date': dueDate != null},
    );
  }

  // --- Actualizar Tarea ---
  Future<void> updateTask(
    String id, {
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    String? lifeAreaId,
  }) async {
    // Local
    await (_database.update(_database.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: Value(title),
        description: Value(description),
        priority: Value(priority),
        dueDate: Value(dueDate),
        lifeAreaId: Value(lifeAreaId),
        isSynced: const Value(false),
      ),
    );
    await _database.customUpdate(
      "UPDATE tasks SET status = 'active', processed_at = NULL, planned_date = ?, completed_at = NULL, missed_at = NULL WHERE id = ?",
      variables: [
        Variable<DateTime>(dueDate),
        Variable.withString(id),
      ],
      updates: {_database.tasks},
    );

    // Remoto
    try {
      await _supabaseClient.from('tasks').update({
        'title': title,
        'description': description,
        'priority': priority,
        'due_date': dueDate?.toIso8601String(),
        'life_area_id': lifeAreaId,
        'status': 'active',
        'processed_at': null,
        'planned_date': dueDate?.toIso8601String(),
        'completed_at': null,
        'missed_at': null,
        'is_synced': true,
      }).eq('id', id);

      await (_database.update(_database.tasks)..where((t) => t.id.equals(id)))
          .write(const TasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync en update task: $e');
    }
  }

  // --- Alternar Estado (Completada/Pendiente) ---
  Future<void> toggleTaskStatus(String id, bool isCompleted) async {
    await processTask(id, didComplete: isCompleted);
  }

  Future<void> processTask(String id, {required bool didComplete}) async {
    final processedAt = DateTime.now();
    final status = didComplete ? 'done' : 'missed';
    final completedAtSql = didComplete ? '?' : 'NULL';
    final missedAtSql = didComplete ? 'NULL' : '?';

    // 1. Local (Marcar como no sincronizado)
    await (_database.update(_database.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        isCompleted: Value(didComplete),
        isSynced: const Value(false),
      ),
    );
    await _database.customUpdate(
      'UPDATE tasks SET status = ?, processed_at = ?, completed_at = $completedAtSql, missed_at = $missedAtSql, is_synced = ? WHERE id = ?',
      variables: [
        Variable.withString(status),
        Variable<DateTime>(processedAt),
        if (didComplete) Variable<DateTime>(processedAt),
        if (!didComplete) Variable<DateTime>(processedAt),
        const Variable<bool>(false),
        Variable.withString(id),
      ],
      updates: {_database.tasks},
    );

    // 2. Remoto
    try {
      await _supabaseClient.from('tasks').update({
        'is_completed': didComplete,
        'status': status,
        'processed_at': processedAt.toIso8601String(),
        'completed_at': didComplete ? processedAt.toIso8601String() : null,
        'missed_at': didComplete ? null : processedAt.toIso8601String(),
      }).eq('id', id);

      // Si tiene éxito, marcar como sincronizado
      await (_database.update(_database.tasks)..where((t) => t.id.equals(id)))
          .write(const TasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error al actualizar estado de tarea: $e. Se sincronizará luego.');
    }

    final task = await (_database.select(_database.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    await _recordActivityEvent(
      eventType: didComplete ? 'task_done' : 'task_missed',
      entityType: 'task',
      entityId: id,
      lifeAreaId: task?.lifeAreaId,
      occurredAt: processedAt,
    );
  }

  // --- Eliminar Tarea ---
  Future<void> deleteTask(String id) async {
    final task = await (_database.select(_database.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    await _recordActivityEvent(
      eventType: 'task_deleted_error',
      entityType: 'task',
      entityId: id,
      lifeAreaId: task?.lifeAreaId,
      occurredAt: DateTime.now(),
    );

    // 1. Registrar borrado pendiente
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'tasks',
            itemId: id,
            action: 'DELETE',
          ),
        );

    // 2. Local
    await (_database.delete(_database.tasks)..where((t) => t.id.equals(id))).go();

    // 3. Remoto
    try {
      await _supabaseClient.from('tasks').delete().eq('id', id);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('tasks') & t.itemId.equals(id)))
          .go();
    } catch (e) {
      print('❌ Error al eliminar tarea: $e. Pendiente de sync.');
    }
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
}
