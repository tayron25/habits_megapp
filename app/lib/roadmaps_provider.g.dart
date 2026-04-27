// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roadmaps_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RoadmapsNotifier)
final roadmapsProvider = RoadmapsNotifierProvider._();

final class RoadmapsNotifierProvider
    extends $StreamNotifierProvider<RoadmapsNotifier, RoadmapsList> {
  RoadmapsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roadmapsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roadmapsNotifierHash();

  @$internal
  @override
  RoadmapsNotifier create() => RoadmapsNotifier();
}

String _$roadmapsNotifierHash() => r'f2429cdc0d27867e7daa11bd8580a25795950a1c';

abstract class _$RoadmapsNotifier extends $StreamNotifier<RoadmapsList> {
  Stream<RoadmapsList> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RoadmapsList>, RoadmapsList>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RoadmapsList>, RoadmapsList>,
              AsyncValue<RoadmapsList>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
