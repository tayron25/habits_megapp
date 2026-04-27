// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'life_areas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LifeAreasNotifier)
final lifeAreasProvider = LifeAreasNotifierProvider._();

final class LifeAreasNotifierProvider
    extends $StreamNotifierProvider<LifeAreasNotifier, LifeAreasList> {
  LifeAreasNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lifeAreasProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lifeAreasNotifierHash();

  @$internal
  @override
  LifeAreasNotifier create() => LifeAreasNotifier();
}

String _$lifeAreasNotifierHash() => r'f409dd9a3c6d50fc92f8e7229d93a8256de083ba';

abstract class _$LifeAreasNotifier extends $StreamNotifier<LifeAreasList> {
  Stream<LifeAreasList> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LifeAreasList>, LifeAreasList>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LifeAreasList>, LifeAreasList>,
              AsyncValue<LifeAreasList>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
