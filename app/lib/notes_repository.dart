import 'dart:convert';

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
        'life_area_id': null,
        'status': 'captured',
        'processed_at': null,
        'converted_to_type': null,
        'converted_to_id': null,
        'note_type': 'quick_note',
        'created_at': createdAt.toIso8601String(),
        'is_synced': false,
        'user_id': _supabaseClient.auth.currentUser?.id,
      });

      await (_database.update(_database.notes)
            ..where((table) => table.id.equals(id)))
          .write(const NotesCompanion(isSynced: Value(true)));
    } catch (e, stack) {
      print('❌ Error de sincronización con Supabase: $e');
      print('🔍 Stacktrace: $stack');
    }

    await _recordActivityEvent(
      eventType: 'note_captured',
      entityType: 'note',
      entityId: id,
      occurredAt: createdAt,
      metadata: {'content_length': text.length},
    );
  }

  Future<void> updateNote(String id, String text) async {
    // Local
    await (_database.update(_database.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        content: Value(text),
        isSynced: const Value(false),
      ),
    );
    await _database.customUpdate(
      "UPDATE notes SET status = 'captured', life_area_id = NULL, processed_at = NULL, converted_to_type = NULL, converted_to_id = NULL WHERE id = ?",
      variables: [Variable.withString(id)],
      updates: {_database.notes},
    );

    // Remoto
    try {
      await _supabaseClient.from('notes').update({
        'content': text,
        'status': 'captured',
        'life_area_id': null,
        'processed_at': null,
        'converted_to_type': null,
        'converted_to_id': null,
        'is_synced': true,
      }).eq('id', id);

      await (_database.update(_database.notes)..where((n) => n.id.equals(id)))
          .write(const NotesCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync al actualizar nota: $e');
    }
  }

  Future<void> processNote(String id, {String? lifeAreaId}) async {
    final processedAt = DateTime.now();
    final status = lifeAreaId == null ? 'discarded' : 'categorized';
    final lifeAreaSql = lifeAreaId == null ? 'NULL' : '?';

    await _database.customUpdate(
      'UPDATE notes SET life_area_id = $lifeAreaSql, status = ?, processed_at = ?, is_synced = ? WHERE id = ?',
      variables: [
        if (lifeAreaId != null) Variable.withString(lifeAreaId),
        Variable.withString(status),
        Variable<DateTime>(processedAt),
        const Variable<bool>(false),
        Variable.withString(id),
      ],
      updates: {_database.notes},
    );

    try {
      await _supabaseClient.from('notes').update({
        'life_area_id': lifeAreaId,
        'status': status,
        'processed_at': processedAt.toIso8601String(),
        'is_synced': true,
      }).eq('id', id);

      await (_database.update(_database.notes)..where((n) => n.id.equals(id)))
          .write(const NotesCompanion(isSynced: Value(true)));
    } catch (e) {
      print('Error de sync al procesar nota: $e');
    }

    await _recordActivityEvent(
      eventType: lifeAreaId == null ? 'note_discarded' : 'note_categorized',
      entityType: 'note',
      entityId: id,
      lifeAreaId: lifeAreaId,
      occurredAt: processedAt,
    );
  }

  Future<void> deleteNote(String id) async {
    await _recordActivityEvent(
      eventType: 'note_deleted_error',
      entityType: 'note',
      entityId: id,
      occurredAt: DateTime.now(),
    );

    // 1. Registrar el borrado pendiente para Supabase
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'notes',
            itemId: id,
            action: 'DELETE',
          ),
        );

    // 2. Borrado Local (Drift)
    await (_database.delete(
      _database.notes,
    )..where((t) => t.id.equals(id))).go();

    // 3. Intento de Borrado Remoto inmediato (opcional, el sync service lo reintentará)
    try {
      await _supabaseClient.from('notes').delete().eq('id', id);
      // Si tuvo éxito inmediato, quitamos de la cola
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('notes') & t.itemId.equals(id)))
          .go();
    } catch (e) {
      print('Nota borrada localmente. Se sincronizará con la nube cuando haya internet.');
    }
  }

  Future<void> _recordActivityEvent({
    required String eventType,
    required String entityType,
    required String entityId,
    String? lifeAreaId,
    required DateTime occurredAt,
    Map<String, Object?>? metadata,
  }) async {
    await _database.customInsert(
      '''
      INSERT OR REPLACE INTO activity_events (
        id, event_type, entity_type, entity_id, life_area_id,
        occurred_at, local_date, source_app, metadata_json, is_synced
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(_uuid.v4()),
        Variable.withString(eventType),
        Variable.withString(entityType),
        Variable.withString(entityId),
        Variable<String>(lifeAreaId),
        Variable<DateTime>(occurredAt),
        Variable<DateTime>(DateTime(occurredAt.year, occurredAt.month, occurredAt.day)),
        Variable.withString('life_os'),
        Variable<String>(metadata == null ? null : jsonEncode(metadata)),
        const Variable<bool>(false),
      ],
    );
  }
}
