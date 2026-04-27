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

  // --- ROADMAPS ---
  Future<void> createRoadmap({
    required String title,
    String? description,
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

    // 2. Remoto
    try {
      await _supabaseClient.from('roadmaps').insert({
        'id': id,
        'title': title,
        'description': description,
        'created_at': now.toIso8601String(),
        'is_synced': true,
      });

      await (_database.update(_database.roadmaps)..where((r) => r.id.equals(id)))
          .write(const RoadmapsCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync al crear roadmap: $e');
    }
  }

  Future<void> deleteRoadmap(String id) async {
    // 1. Local
    await (_database.delete(_database.roadmaps)..where((r) => r.id.equals(id))).go();

    // 2. Remoto
    try {
      await _supabaseClient.from('roadmaps').delete().eq('id', id);
    } catch (e) {
      print('❌ Error al eliminar roadmap: $e');
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
      });

      await (_database.update(_database.roadmapMilestones)..where((m) => m.id.equals(id)))
          .write(const RoadmapMilestonesCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync al crear milestone: $e');
    }
  }

  Future<void> deleteMilestone(String id) async {
    await (_database.delete(_database.roadmapMilestones)..where((m) => m.id.equals(id))).go();
    try {
      await _supabaseClient.from('roadmap_milestones').delete().eq('id', id);
    } catch (e) {
      print('❌ Error al eliminar milestone: $e');
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
        'created_at': now.toIso8601String(),
        'is_synced': true,
      });

      await (_database.update(_database.milestoneTasks)..where((t) => t.id.equals(id)))
          .write(const MilestoneTasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync al crear tarea de milestone: $e');
    }
  }

  Future<void> toggleMilestoneTask(String id, bool isCompleted) async {
    // 1. Local
    await (_database.update(_database.milestoneTasks)..where((t) => t.id.equals(id)))
        .write(MilestoneTasksCompanion(isCompleted: Value(isCompleted)));

    // 2. Remoto
    try {
      await _supabaseClient.from('milestone_tasks').update({'is_completed': isCompleted}).eq('id', id);
    } catch (e) {
      print('❌ Error al actualizar estado de tarea de milestone: $e');
    }
  }

  Future<void> deleteMilestoneTask(String id) async {
    await (_database.delete(_database.milestoneTasks)..where((t) => t.id.equals(id))).go();
    try {
      await _supabaseClient.from('milestone_tasks').delete().eq('id', id);
    } catch (e) {
      print('❌ Error al eliminar tarea de milestone: $e');
    }
  }
}
