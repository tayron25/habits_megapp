import 'dart:async';
import 'package:app/notes_provider.dart';
import 'package:app/sync_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_provider.g.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    database: ref.read(appDatabaseProvider),
    supabase: ref.read(supabaseClientProvider),
  );
});

@riverpod
class SyncNotifier extends _$SyncNotifier {
  Timer? _syncTimer;

  @override
  void build() {
    // Iniciamos un temporizador para sincronizar cada 5 minutos
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => performSync());
    
    // También intentamos sincronizar al iniciar la app
    Future.delayed(const Duration(seconds: 5), () => performSync());

    ref.onDispose(() => _syncTimer?.cancel());
  }

  Future<void> performSync() async {
    final repo = ref.read(syncRepositoryProvider);
    await repo.synchronizeAll();
  }
}
