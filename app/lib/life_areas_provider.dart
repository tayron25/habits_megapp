import 'package:app/local_database.dart';
import 'package:app/notes_provider.dart';
import 'package:app/life_areas_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'life_areas_provider.g.dart';

typedef LifeAreasList = List<LifeArea>;

final lifeAreasRepositoryProvider = Provider<LifeAreasRepository>((ref) {
  return LifeAreasRepository(
    supabaseClient: ref.read(supabaseClientProvider),
    database: ref.read(appDatabaseProvider),
  );
});

@riverpod
class LifeAreasNotifier extends _$LifeAreasNotifier {
  @override
  Stream<LifeAreasList> build() {
    final db = ref.watch(appDatabaseProvider);
    return db.select(db.lifeAreas).watch();
  }

  void addLifeArea(String name, {String? icon}) {
    ref.read(lifeAreasRepositoryProvider).createLifeArea(name: name, icon: icon);
  }

  void removeLifeArea(String id) {
    ref.read(lifeAreasRepositoryProvider).deleteLifeArea(id);
  }
}
