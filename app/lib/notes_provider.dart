import 'package:app/local_database.dart';
import 'package:app/notes_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'notes_provider.g.dart';

typedef NotesList = List<Note>;

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(
    supabaseClient: ref.read(supabaseClientProvider),
    database: ref.read(appDatabaseProvider),
  );
});

@riverpod
class NotesNotifier extends _$NotesNotifier {
  @override
  Stream<NotesList> build() {
    final database = ref.watch(appDatabaseProvider);
    return database.select(database.notes).watch();
  }

  void addNote(String content) {
    ref.read(notesRepositoryProvider).saveNote(content);
  }

  void removeNote(String id) {
    ref.read(notesRepositoryProvider).deleteNote(id);
  }
}
