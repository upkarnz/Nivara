import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nivara/features/memory/data/memory_repository.dart';
import 'package:nivara/features/memory/domain/memory.dart';

void main() {
  group('MemoryRepository', () {
    test('fetchMemories returns list of Memory on 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/memory') {
          return http.Response(
            '[{"id":"1","uid":"u1","content":"Loves hiking","memory_type":"preference","confidence":0.9,"created_at":"2026-05-03T00:00:00Z","last_reinforced":"2026-05-03T00:00:00Z","reinforcement_count":1}]',
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      final repo = MemoryRepository(
        client: mockClient,
        baseUrl: 'http://localhost:8000',
      );

      final memories = await repo.fetchMemories('fake_token');
      expect(memories, isA<List<Memory>>());
      expect(memories.length, 1);
      expect(memories.first.content, 'Loves hiking');
    });

    test('fetchMemories throws on non-200', () async {
      final mockClient = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repo = MemoryRepository(
        client: mockClient,
        baseUrl: 'http://localhost:8000',
      );
      expect(() => repo.fetchMemories('bad_token'), throwsException);
    });

    test('deleteMemory calls DELETE endpoint', () async {
      bool deleteCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE') {
          deleteCalled = true;
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });
      final repo = MemoryRepository(
        client: mockClient,
        baseUrl: 'http://localhost:8000',
      );
      await repo.deleteMemory('fake_token', 'mem1');
      expect(deleteCalled, isTrue);
    });
  });
}
