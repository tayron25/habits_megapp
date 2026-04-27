// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habits_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HabitsNotifier)
final habitsProvider = HabitsNotifierProvider._();

final class HabitsNotifierProvider
    extends $StreamNotifierProvider<HabitsNotifier, HabitWithStatusList> {
  HabitsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitsNotifierHash();

  @$internal
  @override
  HabitsNotifier create() => HabitsNotifier();
}

String _$habitsNotifierHash() => r'7d4269a3ec25d7c6bb0c74116e21c516e6a8f2a6';

abstract class _$HabitsNotifier extends $StreamNotifier<HabitWithStatusList> {
  Stream<HabitWithStatusList> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<HabitWithStatusList>, HabitWithStatusList>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HabitWithStatusList>, HabitWithStatusList>,
              AsyncValue<HabitWithStatusList>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
