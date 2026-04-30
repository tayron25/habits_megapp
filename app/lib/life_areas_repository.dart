import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class LifeAreasRepository {
  LifeAreasRepository({
    required SupabaseClient supabaseClient,
    required AppDatabase database,
  })  : _supabaseClient = supabaseClient,
        _database = database;

  final SupabaseClient _supabaseClient;
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<void> createLifeArea({
    required String name,
    String? icon,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // 1. Local
    await _database.into(_database.lifeAreas).insert(
          LifeAreasCompanion.insert(
            id: id,
            name: name,
            icon: Value(icon),
            createdAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    // 2. Remoto
    try {
      await _supabaseClient.from('life_areas').insert({
        'id': id,
        'name': name,
        'icon': icon,
        'created_at': now.toIso8601String(),
        'is_synced': true,
      });

      await (_database.update(_database.lifeAreas)..where((a) => a.id.equals(id)))
          .write(const LifeAreasCompanion(isSynced: Value(true)));
    } catch (e) {
      print('❌ Error de sync al crear LifeArea: $e');
    }
  }

  Future<void> deleteLifeArea(String id) async {
    // 1. Registrar borrado pendiente
    await _database.into(_database.pendingSyncActions).insert(
          PendingSyncActionsCompanion.insert(
            localTable: 'life_areas',
            itemId: id,
            action: 'DELETE',
          ),
        );

    // 2. Local
    await (_database.delete(_database.lifeAreas)..where((a) => a.id.equals(id))).go();

    // 3. Remoto
    try {
      await _supabaseClient.from('life_areas').delete().eq('id', id);
      await (_database.delete(_database.pendingSyncActions)
            ..where((t) => t.localTable.equals('life_areas') & t.itemId.equals(id)))
          .go();
    } catch (e) {
      print('❌ Error al eliminar LifeArea: $e. Pendiente de sync.');
    }
  }
}
