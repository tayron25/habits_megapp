// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NotesNotifier)
final notesProvider = NotesNotifierProvider._();

final class NotesNotifierProvider
    extends $StreamNotifierProvider<NotesNotifier, NotesList> {
  NotesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notesNotifierHash();

  @$internal
  @override
  NotesNotifier create() => NotesNotifier();
}

String _$notesNotifierHash() => r'db8003efa85cc92123326345f058990a89a55c2b';

abstract class _$NotesNotifier extends $StreamNotifier<NotesList> {
  Stream<NotesList> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<NotesList>, NotesList>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NotesList>, NotesList>,
              AsyncValue<NotesList>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
