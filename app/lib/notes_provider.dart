import 'package:app/local_database.dart';
import 'package:app/notes_repository.dart';
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
    return database
        .customSelect(
          "SELECT id, content, created_at, is_synced FROM notes WHERE status = 'captured' ORDER BY created_at DESC",
          readsFrom: {database.notes},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => Note(
                  id: row.read<String>('id'),
                  content: row.read<String>('content'),
                  createdAt: row.read<DateTime>('created_at'),
                  isSynced: row.read<bool>('is_synced'),
                ),
              )
              .toList(),
        );
  }

  void addNote(String content) {
    ref.read(notesRepositoryProvider).saveNote(content);
  }

  void updateNote(String id, String content) {
    ref.read(notesRepositoryProvider).updateNote(id, content);
  }

  void removeNote(String id) {
    ref.read(notesRepositoryProvider).deleteNote(id);
  }

  void processNote(String id, {String? lifeAreaId}) {
    ref.read(notesRepositoryProvider).processNote(id, lifeAreaId: lifeAreaId);
  }
}
