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
        'created_at': now.toIso8601String(),
        'is_synced': true,
      });

      await (_database.update(_database.tasks)..where((t) => t.id.equals(id)))
          .write(const TasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync en tarea: $e');
    }
  }

  // --- Alternar Estado (Completada/Pendiente) ---
  Future<void> toggleTaskStatus(String id, bool isCompleted) async {
    // 1. Local (Marcar como no sincronizado)
    await (_database.update(_database.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        isCompleted: Value(isCompleted),
        isSynced: const Value(false),
      ),
    );

    // 2. Remoto
    try {
      await _supabaseClient.from('tasks').update({'is_completed': isCompleted}).eq('id', id);

      // Si tiene éxito, marcar como sincronizado
      await (_database.update(_database.tasks)..where((t) => t.id.equals(id)))
          .write(const TasksCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error al actualizar estado de tarea: $e. Se sincronizará luego.');
    }
  }

  // --- Eliminar Tarea ---
  Future<void> deleteTask(String id) async {
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
}