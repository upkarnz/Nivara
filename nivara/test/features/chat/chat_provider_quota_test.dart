import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';
import 'package:nivara/features/chat/presentation/providers/chat_provider.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/presentation/providers/mood_playlist_provider.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';
import 'package:nivara/features/profile/presentation/providers/profile_provider.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';
import 'package:nivara/features/subscription/data/quota_repository.dart';
import 'package:nivara/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:nivara/shared/models/user_profile.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHermesClient extends HermesClient {
  _FakeHermesClient() : super(baseUrl: 'http://localhost');

  @override
  Stream<ChatChunk> chatStream({
    required List<Map<String, String>> messages,
    required String assistantName,
    String aiModel = 'gemini_flash',
  }) async* {
    yield const TextChunk('Hello');
    yield const DoneChunk();
  }
}

class _FakeAiModel extends AiModelNotifier {
  @override
  Future<String> build() async => 'gemini_flash';
}

class _EmptyMusicNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState();
}

// Quota repository that records calls (extends abstract base — no Firebase needed)
class _RecordingQuotaRepo extends QuotaRepository {
  int messageIncrements = 0;
  int graceIncrements = 0;

  @override
  Stream<QuotaDoc> getQuota() => const Stream.empty();

  @override
  Future<void> resetIfNewPeriod() async {}

  @override
  Future<void> incrementMessage() async => messageIncrements++;

  @override
  Future<void> incrementGrace() async => graceIncrements++;

  @override
  Future<void> setModel(String model) async {}
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({
  required _RecordingQuotaRepo repo,
  bool exhausted = false,
  bool inGrace = false,
  int graceRemaining = 3,
}) {
  final quotaState = QuotaState(
    messagesUsed: exhausted || inGrace ? 3000 : 100,
    monthlyQuota: 3000,
    remaining: exhausted || inGrace ? 0 : 2900,
    graceUsed: exhausted ? 3 : inGrace ? 1 : 0,
    inGrace: inGrace,
    exhausted: exhausted,
    graceRemaining: graceRemaining,
  );
  return ProviderContainer(
    overrides: [
      hermesClientProvider.overrideWithValue(_FakeHermesClient()),
      moodToneProvider.overrideWith((_) async => null),
      assistantConfigProvider.overrideWith(
          (_) async => const AssistantConfig(
                name: 'Rocky',
                voice: 'neutral',
                speed: 'normal',
                style: 'friendly',
                wakePhrase: 'Hey Rocky',
                aiModel: 'gemini_flash',
              )),
      aiModelNotifierProvider.overrideWith(_FakeAiModel.new),
      moodPlaylistProvider.overrideWith((_) async => null),
      musicPlayerNotifierProvider.overrideWith(_EmptyMusicNotifier.new),
      quotaRepositoryProvider.overrideWithValue(repo),
      quotaProvider.overrideWith((_) => Stream.value(quotaState)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('sendMessage increments messagesUsed on normal send', () async {
    final repo = _RecordingQuotaRepo();
    final container = _makeContainer(repo: repo);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('hello');

    expect(repo.messageIncrements, 1);
    expect(repo.graceIncrements, 0);
  });

  test('sendMessage increments graceUsed when inGrace', () async {
    final repo = _RecordingQuotaRepo();
    final container =
        _makeContainer(repo: repo, inGrace: true, graceRemaining: 2);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('hello');

    expect(repo.graceIncrements, 1);
    expect(repo.messageIncrements, 0);
  });

  test('sendMessage does nothing when exhausted', () async {
    final repo = _RecordingQuotaRepo();
    final container = _makeContainer(repo: repo, exhausted: true);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('hello');

    expect(repo.messageIncrements, 0);
    expect(repo.graceIncrements, 0);
    // State should be unchanged (no assistant message appended)
    expect(container.read(chatNotifierProvider).length, 0);
  });
}
