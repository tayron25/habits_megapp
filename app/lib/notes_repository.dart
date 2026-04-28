import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NotesRepository {
  NotesRepository({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  }) : _supabaseClient = supabaseClient,
       _database = database;

  final SupabaseClient _supabaseClient;
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<void> saveNote(String text) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now();

    await _database
        .into(_database.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            content: text,
            createdAt: Value(createdAt),
            isSynced: const Value(false),
          ),
        );

    try {
      await _supabaseClient.from('notes').insert({
        'id': id,
        'content': text,
        'created_at': createdAt.toIso8601String(),
        'is_synced': false,
      });

      await (_database.update(_database.notes)
            ..where((table) => table.id.equals(id)))
          .write(const NotesCompanion(isSynced: Value(true)));
    } catch (e, stack) {
      print('❌ Error de sincronización con Supabase: $e');
      print('🔍 Stacktrace: $stack');
    }
  }

  Future<void> deleteNote(String id) async {
    // 1. Borrado Local (Drift)
    await (_database.delete(
      _database.notes,
    )..where((t) => t.id.equals(id))).go();

    // 2. Borrado Remoto (Supabase)
    try {
      await _supabaseClient.from('notes').delete().eq('id', id);
    } catch (e) {
      // Si falla el internet, al menos ya se borró del cel.
      // Podríamos implementar una lógica de "pendientes por borrar" más adelante.
      print('Error al sincronizar borrado de nota: $e');
    }
  }
}
