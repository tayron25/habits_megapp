import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importaciones absolutas estandarizadas
import 'package:app/local_database.dart';
import 'package:app/notes_provider.dart'; 
import 'package:app/tasks_repository.dart';

part 'tasks_provider.g.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(
    supabaseClient: ref.read(supabaseClientProvider),
    database: ref.read(appDatabaseProvider),
  );
});

typedef TasksList = List<Task>;

@riverpod
class TasksNotifier extends _$TasksNotifier {
  @override
  Stream<TasksList> build() {
    final database = ref.watch(appDatabaseProvider);
    return database
        .customSelect(
          "SELECT id, title, description, priority, due_date, life_area_id, is_completed, created_at, is_synced FROM tasks WHERE status = 'active' ORDER BY created_at DESC",
          readsFrom: {database.tasks},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => Task(
                  id: row.read<String>('id'),
                  title: row.read<String>('title'),
                  description: row.readNullable<String>('description'),
                  priority: row.read<String>('priority'),
                  dueDate: row.readNullable<DateTime>('due_date'),
                  lifeAreaId: row.readNullable<String>('life_area_id'),
                  isCompleted: row.read<bool>('is_completed'),
                  createdAt: row.read<DateTime>('created_at'),
                  isSynced: row.read<bool>('is_synced'),
                ),
              )
              .toList(),
        );
  }

  void addTask({
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    String? lifeAreaId,
  }) {
    ref.read(tasksRepositoryProvider).createTask(
          title: title,
          description: description,
          priority: priority,
          dueDate: dueDate,
          lifeAreaId: lifeAreaId,
        );
  }

  void updateTask(
    String id, {
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    String? lifeAreaId,
  }) {
    ref.read(tasksRepositoryProvider).updateTask(
          id,
          title: title,
          description: description,
          priority: priority,
          dueDate: dueDate,
          lifeAreaId: lifeAreaId,
        );
  }

  void toggleTask(String id, bool isCompleted) {
    ref.read(tasksRepositoryProvider).toggleTaskStatus(id, isCompleted);
  }

  void removeTask(String id) {
    ref.read(tasksRepositoryProvider).deleteTask(id);
  }

  void processTask(String id, {required bool didComplete}) {
    ref.read(tasksRepositoryProvider).processTask(id, didComplete: didComplete);
  }
}
