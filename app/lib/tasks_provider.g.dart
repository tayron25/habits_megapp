// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TasksNotifier)
final tasksProvider = TasksNotifierProvider._();

final class TasksNotifierProvider
    extends $StreamNotifierProvider<TasksNotifier, TasksList> {
  TasksNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tasksNotifierHash();

  @$internal
  @override
  TasksNotifier create() => TasksNotifier();
}

String _$tasksNotifierHash() => r'4bceb779ef4d045aa1373ca0b2dbbafe0a0fde73';

abstract class _$TasksNotifier extends $StreamNotifier<TasksList> {
  Stream<TasksList> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TasksList>, TasksList>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TasksList>, TasksList>,
              AsyncValue<TasksList>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
