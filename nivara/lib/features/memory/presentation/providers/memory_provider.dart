import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/memory_repository.dart';
import '../../domain/memory.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(baseUrl: 'http://localhost:8000');
});

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
}

final memoryNotifierProvider =
    AsyncNotifierProvider<MemoryNotifier, List<Memory>>(MemoryNotifier.new);
