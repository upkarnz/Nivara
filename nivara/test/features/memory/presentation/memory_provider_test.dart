import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/memory/data/memory_repository.dart';
import 'package:nivara/features/memory/domain/memory.dart';
import 'package:nivara/features/memory/presentation/providers/memory_provider.dart';

class FakeMemoryRepository extends MemoryRepository {
  FakeMemoryRepository() : super(baseUrl: 'http://localhost');

  final List<Memory> _memories = [];

  void seedMemories(List<Memory> memories) => _memories.addAll(memories);

  @override
  Future<List<Memory>> fetchMemories(String idToken) async =>
      List.from(_memories);

  @override
  Future<void> deleteMemory(String idToken, String memoryId) async {
    _memories.removeWhere((m) => m.id == memoryId);
  }
}

void main() {
  test('memoryNotifierProvider loads memories', () async {
    final fakeRepo = FakeMemoryRepository();
    final testMemory = Memory(
      id: '1',
      uid: 'u1',
      content: 'Loves hiking',
      memoryType: 'preference',
      confidence: 0.9,
      createdAt: '2026-05-03T00:00:00Z',
      lastReinforced: '2026-05-03T00:00:00Z',
      reinforcementCount: 1,
    );

    fakeRepo.seedMemories([testMemory]);

    final container = ProviderContainer(
      overrides: [
        memoryRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(memoryNotifierProvider.notifier);
    await notifier.loadMemories('fake_token');

    final state = container.read(memoryNotifierProvider);
    expect(state, isA<AsyncData<List<Memory>>>());
    expect(state.value?.length, 1);
    expect(state.value?.first.content, 'Loves hiking');
  });

  test('memoryNotifierProvider deletes a memory', () async {
    final fakeRepo = FakeMemoryRepository();
    fakeRepo.seedMemories([
      Memory(
        id: '1',
        uid: 'u1',
        content: 'Loves hiking',
        memoryType: 'preference',
        confidence: 0.9,
        createdAt: '2026-05-03T00:00:00Z',
        lastReinforced: '2026-05-03T00:00:00Z',
        reinforcementCount: 1,
      ),
      Memory(
        id: '2',
        uid: 'u1',
        content: 'Hates rain',
        memoryType: 'preference',
        confidence: 0.8,
        createdAt: '2026-05-03T00:00:00Z',
        lastReinforced: '2026-05-03T00:00:00Z',
        reinforcementCount: 1,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        memoryRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(memoryNotifierProvider.notifier);
    await notifier.loadMemories('fake_token');
    await notifier.deleteMemory('fake_token', '1');

    final state = container.read(memoryNotifierProvider);
    expect(state.value?.length, 1);
    expect(state.value?.first.id, '2');
  });
}
