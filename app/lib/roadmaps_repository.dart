import 'dart:convert';

import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class RoadmapsRepository {
  RoadmapsRepository({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  })  : _supabaseClient = supabaseClient,
        _database = database;

  final SupabaseClient _supabaseClient;
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  bool _isMissingOptionalRoadmapColumn(Object error) {
    final text = error.toString();
    return text.contains('PGRST204') && (text.contains('show_on_home') || text.contains('life_area_id'));
  }

  Future<void> _markRoadmapSynced(String id) async {
    await (_database.update(_database.roadmaps)..where((r) => r.id.equals(id)))
        .write(const RoadmapsCompanion(isSynced: Value(true)));
  }

  // --- ROADMAPS ---
  Future<void> createRoadmap({
    required String title,
    String? description,
    bool showOnHome = true,
    String? lifeAreaId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // 1. Local
    await _database.into(_database.roadmaps).insert(
          RoadmapsCompanion.insert(
            id: id,
            title: title,
            description: Value(description),
            createdAt: Value(now),
            isSynced: const Value(false),
          ),
        );
    await _database.customUpdate(
      'UPDATE roadmaps SET show_on_home = ?, life_area_id = ? WHERE id = ?',
      variables: [
        Variable<bool>(showOnHome),
        Variable<String>(lifeAreaId),
        Variable.withString(id),
      ],
      updates: {_database.roadmaps},
    );

    // 2. Remoto
    final payload = {
      'id': id,
      'title': title,
      'description': description,
      'show_on_home': showOnHome,
      'life_area_id': lifeAreaId,
      'created_at': now.toIso8601String(),
      'is_synced': true,
      'user_id': _supabaseClient.auth.currentUser?.id,
    };

    try {
      await _supabaseClient.from('roadmaps').insert(payload);

      await _markRoadmapSynced(id);
    } catch (e) {
      if (_isMissingOptionalRoadmapColumn(e)) {
        try {
          final fallbackPayload = Map<String, dynamic>.from(payload)
            ..remove('show_on_home')
            ..remove('life_area_id');
          await _supabaseClient.from('roadmaps').insert(fallbackPayload);
          await _markRoadmapSynced(id);
          return;
        } catch (fallbackError) {
          print('Error de sync al crear roadmap sin show_on_home: $fallbackError');
        }
      }
      print('❌ Error de sync al crear roadmap: $e');
    }

    await _recordActivityEvent(
      eventType: 'roadmap_created',
      entityType: 'roadmap',
      entityId: id,
      lifeAreaId: lifeAreaId,
      occurredAt: now,
    );
  }

  Future<void> updateRoadmap(
    String id, {
    required String title,
    String? description,
    bool showOnHome = true,
    String? lifeAreaId,
  }) async {
    final current = await _database.customSelect(
      'SELECT life_area_id FROM roadmaps WHERE id = ?',
      variables: [Variable.withString(id)],
      readsFrom: {_database.roadmaps},
    ).getSingleOrNull();
    final resolvedLifeAreaId = lifeAreaId ?? current?.readNullable<String>('life_area_id');

    // Local
    await (_database.update(_database.roadmaps)..where((r) => r.id.equals(id))).write(
      RoadmapsCompanion(
        title: Value(title),
        description: Value(description),
        isSynced: const Value(false),
      ),
    );
    await _database.customUpdate(
      'UPDATE roadmaps SET show_on_home = ?, life_area_id = ? WHERE id = ?',
      variables: [
        Variable<bool>(showOnHome),
        Variable<String>(resolvedLifeAreaId),
        Variable.withString(id),
      ],
      updates: {_database.roadmaps},
    );

    // Remoto
    final payload = {
      'title': title,
      'description': description,
      'show_on_home': showOnHome,
      'life_area_id': resolvedLifeAreaId,
      'is_synced': true,
    };

    try {
      await _supabaseClient.from('roadmaps').update(payload).eq('id', id);

      await _markRoadmapSynced(id);
    } catch (e) {
      if (_isMissingOptionalRoadmapColumn(e)) {
        try {
          final fallbackPayload = Map<String, dynamic>.from(payload)
            ..remove('show_on_home')
            ..remove('life_area_id');
          await _supabaseClient.from('roadmaps').update(fallbackPayload).eq('id', id);
          await _markRoadmapSynced(id);
          return;
        } catch (fallbackError) {
          print('Error de sync al actualizar roadmap sin show_on_home: $fallbackError');
        }
      }
      print('Error de sync al actualizar roadmap: $e');
    }
  }

  Future<void> deleteRoadmap(String id) async {
    // 1. Registrar borrado pendiente
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'roadmaps',
            itemId: id,
            action: 'DELETE',
          ),
        );

    // 2. Local
    await (_database.delete(_database.roadmaps)..where((r) => r.id.equals(id))).go();

    // 3. Remoto
    try {
      await _supabaseClient.from('roadmaps').delete().eq('id', id);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('roadmaps') & t.itemId.equals(id)))
          .go();
    } catch (e) {
      print('❌ Error al eliminar roadmap: $e. Pendiente de sync.');
    }
  }

  // --- HITOS (MILESTONES) ---
  Future<void> addMilestone({
    required String roadmapId,
    required String title,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // 1. Local
    await _database.into(_database.roadmapMilestones).insert(
          RoadmapMilestonesCompanion.insert(
            id: id,
            roadmapId: roadmapId,
            title: title,
            createdAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    // 2. Remoto
    try {
      await _supabaseClient.from('roadmap_milestones').insert({
        'id': id,
        'roadmap_id': roadmapId,
        'title': title,
        'created_at': now.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });

      await (_database.update(_database.roadmapMilestones)..where((m) => m.id.equals(id)))
          .write(const RoadmapMilestonesCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync al crear milestone: $e');
    }
  }

  Future<void> deleteMilestone(String id) async {
    // 1. Registrar borrado pendiente
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'roadmap_milestones',
            itemId: id,
            action: 'DELETE',
          ),
        );

    // 2. Local
    await (_database.delete(_database.roadmapMilestones)..where((m) => m.id.equals(id))).go();

    // 3. Remoto
    try {
      await _supabaseClient.from('roadmap_milestones').delete().eq('id', id);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('roadmap_milestones') & t.itemId.equals(id)))
          .go();
    } catch (e) {
      print('❌ Error al eliminar milestone: $e. Pendiente de sync.');
    }
  }

  // --- TAREAS DEL HITO (MILESTONE TASKS) ---
  Future<void> addTaskToMilestone({
    required String milestoneId,
    required String title,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // 1. Local
    await _database.into(_database.milestoneTasks).insert(
          MilestoneTasksCompanion.insert(
            id: id,
            milestoneId: milestoneId,
            title: title,
            isCompleted: const Value(false),
            createdAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    // 2. Remoto
    try {
      await _supabaseClient.from('milestone_tasks').insert({
        'id': id,
        'milestone_id': milestoneId,
        'title': title,
        'is_completed': false,
        'status': 'active',
        'completed_at': null,
        'created_at': now.toIso8601String(),
        'is_synced': true,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });

      await (_database.update(_database.milestoneTasks)..where((t) => t.id.equals(id)))
          .write(const MilestoneTasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync al crear tarea de milestone: $e');
    }
  }

  Future<void> toggleMilestoneTask(String id, bool isCompleted) async {
    final completedAt = isCompleted ? DateTime.now() : null;
    final completedAtSql = completedAt == null ? 'NULL' : '?';
    final status = isCompleted ? 'done' : 'active';

    // 1. Local
    await (_database.update(_database.milestoneTasks)..where((t) => t.id.equals(id)))
        .write(MilestoneTasksCompanion(
          isCompleted: Value(isCompleted),
          isSynced: const Value(false),
        ));
    await _database.customUpdate(
      'UPDATE milestone_tasks SET status = ?, completed_at = $completedAtSql WHERE id = ?',
      variables: [
        Variable.withString(status),
        if (completedAt != null) Variable<DateTime>(completedAt),
        Variable.withString(id),
      ],
      updates: {_database.milestoneTasks},
    );

    // 2. Remoto
    try {
      await _supabaseClient.from('milestone_tasks').update({
        'is_completed': isCompleted,
        'status': status,
        'completed_at': completedAt?.toIso8601String(),
      }).eq('id', id);
      await (_database.update(_database.milestoneTasks)..where((t) => t.id.equals(id)))
          .write(const MilestoneTasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error al actualizar estado de tarea de milestone: $e. Pendiente de sync.');
    }

    final context = await _database.customSelect(
      '''
      SELECT roadmaps.id AS roadmap_id, roadmaps.life_area_id AS life_area_id
      FROM milestone_tasks
      INNER JOIN roadmap_milestones ON roadmap_milestones.id = milestone_tasks.milestone_id
      INNER JOIN roadmaps ON roadmaps.id = roadmap_milestones.roadmap_id
      WHERE milestone_tasks.id = ?
      ''',
      variables: [Variable.withString(id)],
      readsFrom: {_database.milestoneTasks, _database.roadmapMilestones, _database.roadmaps},
    ).getSingleOrNull();
    await _recordActivityEvent(
      eventType: isCompleted ? 'roadmap_task_completed' : 'roadmap_task_reopened',
      entityType: 'milestone_task',
      entityId: id,
      lifeAreaId: context?.readNullable<String>('life_area_id'),
      occurredAt: completedAt ?? DateTime.now(),
      metadata: {'roadmap_id': context?.readNullable<String>('roadmap_id')},
    );
  }

  Future<void> deleteMilestoneTask(String id) async {
    // 1. Registrar borrado pendiente
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'milestone_tasks',
            itemId: id,
            action: 'DELETE',
          ),
        );

    // 2. Local
    await (_database.delete(_database.milestoneTasks)..where((t) => t.id.equals(id))).go();

    // 3. Remoto
    try {
      await _supabaseClient.from('milestone_tasks').delete().eq('id', id);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('milestone_tasks') & t.itemId.equals(id)))
          .go();
    } catch (e) {
      print('❌ Error al eliminar tarea de milestone: $e. Pendiente de sync.');
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
