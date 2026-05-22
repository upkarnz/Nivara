import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/memory_repository.dart';
import '../../domain/memory.dart';

part 'memory_provider.g.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(
      baseUrl: 'https://nivara-production.up.railway.app');
});

/// Auto-fetches the user's memories on first access and keeps them alive for
/// the session. Used by ChatNotifier to inject memory context into every
/// AI request so the agent can recall past conversations and user preferences.
@Riverpod(keepAlive: true)
Future<List<Memory>> userMemories(UserMemoriesRef ref) async {
  final idToken = await ref.watch(firebaseIdTokenProvider.future);
  return ref.read(memoryRepositoryProvider).fetchMemories(idToken);
}

class MemoryNotifier extends AsyncNotifier<List<Memory>> {
  @override
  Future<List<Memory>> build() async => [];

  Future<void> loadMemories(String idToken) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(memoryRepositoryProvider).fetchMemories(idToken),
    );
  }

  Future<void> deleteMemory(String idToken, String memoryId) async {
    await ref
        .read(memoryRepositoryProvider)
        .deleteMemory(idToken, memoryId);
    await loadMemories(idToken);
  }

  Future<void> updateMemory(
      String idToken, String memoryId, String newContent) async {
    try {
      await ref
          .read(memoryRepositoryProvider)
          .updateMemory(idToken, memoryId, newContent);
    } catch (_) {
      // Backend may not support updates; reload to keep UI consistent.
    }
    await loadMemories(idToken);
  }
}

final memoryNotifierProvider =
    AsyncNotifierProvider<MemoryNotifier, List<Memory>>(MemoryNotifier.new);
