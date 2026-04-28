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

String _$habitsNotifierHash() => r'309d7dd55e8d6b39a88bb0eac8d9104b904c9b0b';

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
