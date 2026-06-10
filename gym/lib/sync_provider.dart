import 'dart:async';
import 'package:gym/local_database.dart';
import 'package:gym/sync_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'sync_provider.g.dart';

// Definimos los providers base que se usaban en app/notes_provider.dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

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
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => performSync());
    Future.delayed(const Duration(seconds: 5), () => performSync());
    ref.onDispose(() => _syncTimer?.cancel());
  }

  Future<void> performSync() async {
    final supabase = ref.read(supabaseClientProvider);
    if (supabase.auth.currentUser == null) {
      return;
    }
    final repo = ref.read(syncRepositoryProvider);
    await repo.synchronizeAll();
  }
}
