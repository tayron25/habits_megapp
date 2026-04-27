// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_workout_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ActiveWorkoutNotifier)
final activeWorkoutProvider = ActiveWorkoutNotifierProvider._();

final class ActiveWorkoutNotifierProvider
    extends
        $NotifierProvider<ActiveWorkoutNotifier, Map<String, List<SetDraft>>> {
  ActiveWorkoutNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeWorkoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeWorkoutNotifierHash();

  @$internal
  @override
  ActiveWorkoutNotifier create() => ActiveWorkoutNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, List<SetDraft>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, List<SetDraft>>>(value),
    );
  }
}

String _$activeWorkoutNotifierHash() =>
    r'948e80fed763a48e06bb991bfab04493598f9044';

abstract class _$ActiveWorkoutNotifier
    extends $Notifier<Map<String, List<SetDraft>>> {
  Map<String, List<SetDraft>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<Map<String, List<SetDraft>>, Map<String, List<SetDraft>>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, List<SetDraft>>,
                Map<String, List<SetDraft>>
              >,
              Map<String, List<SetDraft>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
