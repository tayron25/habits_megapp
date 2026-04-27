// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gym_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GymTemplatesNotifier)
final gymTemplatesProvider = GymTemplatesNotifierProvider._();

final class GymTemplatesNotifierProvider
    extends
        $StreamNotifierProvider<
          GymTemplatesNotifier,
          List<WorkoutTemplateWithExercises>
        > {
  GymTemplatesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gymTemplatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gymTemplatesNotifierHash();

  @$internal
  @override
  GymTemplatesNotifier create() => GymTemplatesNotifier();
}

String _$gymTemplatesNotifierHash() =>
    r'f82d6f5d3256335e7b2cf417e22b4e9d3a5edc71';

abstract class _$GymTemplatesNotifier
    extends $StreamNotifier<List<WorkoutTemplateWithExercises>> {
  Stream<List<WorkoutTemplateWithExercises>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<WorkoutTemplateWithExercises>>,
              List<WorkoutTemplateWithExercises>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<WorkoutTemplateWithExercises>>,
                List<WorkoutTemplateWithExercises>
              >,
              AsyncValue<List<WorkoutTemplateWithExercises>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
