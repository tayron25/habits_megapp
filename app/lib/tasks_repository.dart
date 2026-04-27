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
    // 1. Local
    await (_database.update(_database.tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(isCompleted: Value(isCompleted)));

    // 2. Remoto
    try {
      await _supabaseClient
          .from('tasks')
          .update({'is_completed': isCompleted})
          .eq('id', id);
    } catch (e) {
      print('❌ Error al actualizar estado de tarea: $e');
    }
  }

  // --- Eliminar Tarea ---
  Future<void> deleteTask(String id) async {
    await (_database.delete(_database.tasks)..where((t) => t.id.equals(id))).go();
    
    try {
      await _supabaseClient.from('tasks').delete().eq('id', id);
    } catch (e) {
      print('❌ Error al eliminar tarea: $e');
    }
  }
}