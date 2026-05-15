import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';
import 'package:nivara/features/chat/presentation/providers/chat_provider.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/profile/presentation/providers/profile_provider.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';
import 'package:nivara/shared/models/user_profile.dart';

/// Fake HermesClient that captures the messages list passed to chatStream.
class FakeHermesClient extends HermesClient {
  FakeHermesClient() : super(baseUrl: 'http://localhost');

  List<Map<String, String>>? capturedMessages;

  @override
  Stream<ChatChunk> chatStream({
    required List<Map<String, String>> messages,
    required String assistantName,
    String aiModel = 'claude',
  }) async* {
    capturedMessages = messages;
    yield const TextChunk('Hello');
    yield const DoneChunk();
  }
}

/// Fake AiModelNotifier that returns 'claude' without touching SharedPreferences.
class FakeAiModelNotifier extends AiModelNotifier {
  @override
  Future<String> build() async => 'claude';
}

ProviderContainer _buildContainer({
  required FakeHermesClient fakeClient,
  String? toneHint,
}) {
  return ProviderContainer(
    overrides: [
      hermesClientProvider.overrideWithValue(fakeClient),
      moodToneProvider.overrideWith((ref) => Future.value(toneHint)),
      assistantConfigProvider.overrideWith(
        (ref) async => const AssistantConfig(
          name: 'Rocky',
          voice: 'neutral',
          speed: 'normal',
          style: 'friendly',
          wakePhrase: 'Hey Rocky',
          aiModel: 'claude',
        ),
      ),
      aiModelNotifierProvider.overrideWith(FakeAiModelNotifier.new),
    ],
  );
}

void main() {
  group('ChatNotifier tone injection', () {
    test('prepends system message when moodToneProvider returns a hint',
        () async {
      final client = FakeHermesClient();
      final container = _buildContainer(
        fakeClient: client,
        toneHint: 'Be warm and gentle. Avoid upbeat openers.',
      );
      addTearDown(container.dispose);

      await container
          .read(chatNotifierProvider.notifier)
          .sendMessage('Hi');

      expect(client.capturedMessages, isNotNull);
      expect(client.capturedMessages!.first['role'], 'system');
      expect(
        client.capturedMessages!.first['content'],
        'Be warm and gentle. Avoid upbeat openers.',
      );
    });

    test('does NOT prepend system message when moodToneProvider returns null',
        () async {
      final client = FakeHermesClient();
      final container = _buildContainer(
        fakeClient: client,
        toneHint: null,
      );
      addTearDown(container.dispose);

      await container
          .read(chatNotifierProvider.notifier)
          .sendMessage('Hi');

      expect(client.capturedMessages, isNotNull);
      expect(
        client.capturedMessages!.any((m) => m['role'] == 'system'),
        isFalse,
      );
    });

    test('tone hint is NOT stored as a ChatMessage in state', () async {
      final client = FakeHermesClient();
      final container = _buildContainer(
        fakeClient: client,
        toneHint: 'Keep your tone calm and measured.',
      );
      addTearDown(container.dispose);

      await container
          .read(chatNotifierProvider.notifier)
          .sendMessage('Hi');

      final messages = container.read(chatNotifierProvider);
      final systemMsgs = messages.where((m) => m.content.contains('calm'));
      expect(systemMsgs, isEmpty);
    });

    test('uses default tone (no system msg) when moodToneProvider throws',
        () async {
      final client = FakeHermesClient();
      final container = ProviderContainer(
        overrides: [
          hermesClientProvider.overrideWithValue(client),
          moodToneProvider.overrideWith(
              (ref) => Future.error(Exception('mood error'))),
          assistantConfigProvider.overrideWith(
            (ref) async => const AssistantConfig(
              name: 'Rocky',
              voice: 'neutral',
              speed: 'normal',
              style: 'friendly',
              wakePhrase: 'Hey Rocky',
              aiModel: 'claude',
            ),
          ),
          aiModelNotifierProvider.overrideWith(FakeAiModelNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatNotifierProvider.notifier)
          .sendMessage('Hi');

      expect(client.capturedMessages, isNotNull);
      expect(
        client.capturedMessages!.any((m) => m['role'] == 'system'),
        isFalse,
      );
    });
  });
}
