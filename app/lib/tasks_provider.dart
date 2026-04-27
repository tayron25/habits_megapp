import 'package:drift/drift.dart';
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
    return (database.select(database.tasks)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  void addTask({
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
  }) {
    ref.read(tasksRepositoryProvider).createTask(
          title: title,
          description: description,
          priority: priority,
          dueDate: dueDate,
        );
  }

  void toggleTask(String id, bool isCompleted) {
    ref.read(tasksRepositoryProvider).toggleTaskStatus(id, isCompleted);
  }

  void removeTask(String id) {
    ref.read(tasksRepositoryProvider).deleteTask(id);
  }
}