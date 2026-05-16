import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';
import 'package:nivara/features/chat/presentation/providers/chat_provider.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/mood_playlist_provider.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';
import 'package:nivara/features/profile/presentation/providers/profile_provider.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';
import 'package:nivara/shared/models/user_profile.dart';

// Re-use the FakeHermesClient from the tone test.
class _FakeHermesClient extends HermesClient {
  _FakeHermesClient() : super(baseUrl: 'http://localhost');

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

class _FakeAiModelNotifier extends AiModelNotifier {
  @override
  Future<String> build() async => 'claude';
}

/// Notifier stub — no track playing.
class _EmptyMusicNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState();
}

/// Notifier stub — track currently loaded/playing.
class _PlayingMusicNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState(
        isPlaying: true,
        currentTrack: MusicTrack(
          id: 'calm_01',
          title: 'Morning Mist',
          artist: 'Ambient Studio',
          duration: Duration(minutes: 4),
          moodCategory: MoodCategory.calm,
          assetPath: 'assets/music/calm/calm_01.mp3',
        ),
      );
}

const _calmPlaylist = MusicPlaylist(
  moodCategory: MoodCategory.calm,
  tracks: [],
);

ProviderContainer _buildContainer({
  required _FakeHermesClient fakeClient,
  required MusicPlayerNotifier Function() notifierFactory,
  MusicPlaylist? playlist,
}) {
  return ProviderContainer(
    overrides: [
      hermesClientProvider.overrideWithValue(fakeClient),
      moodToneProvider.overrideWith((_) async => null),
      assistantConfigProvider.overrideWith(
        (_) async => const AssistantConfig(
          name: 'Rocky',
          voice: 'neutral',
          speed: 'normal',
          style: 'friendly',
          wakePhrase: 'Hey Rocky',
          aiModel: 'claude',
        ),
      ),
      aiModelNotifierProvider.overrideWith(_FakeAiModelNotifier.new),
      musicPlayerNotifierProvider.overrideWith(notifierFactory),
      musicServiceProvider.overrideWith((_) => throw UnimplementedError()),
      musicRepositoryProvider.overrideWith((_) => throw UnimplementedError()),
      moodPlaylistProvider.overrideWith((_) async => playlist),
    ],
  );
}

void main() {
  group('ChatNotifier music suggestion injection', () {
    test('appends music suggestion hint when mood is calm and nothing is playing',
        () async {
      final fakeClient = _FakeHermesClient();
      final container = _buildContainer(
        fakeClient: fakeClient,
        notifierFactory: _EmptyMusicNotifier.new,
        playlist: _calmPlaylist, // calm playlist → isCalm=true
      );
      addTearDown(container.dispose);

      await container.read(chatNotifierProvider.notifier).sendMessage('Hey');

      final messages = fakeClient.capturedMessages ?? [];
      final systemMessages =
          messages.where((m) => m['role'] == 'system').toList();

      expect(
        systemMessages.any((m) =>
            (m['content'] ?? '').contains('suggest') &&
            (m['content'] ?? '').contains('music')),
        isTrue,
        reason: 'Expected a system message hinting to suggest music',
      );
    });

    test('does not append hint when music is already playing', () async {
      final fakeClient = _FakeHermesClient();
      final container = _buildContainer(
        fakeClient: fakeClient,
        notifierFactory: _PlayingMusicNotifier.new,
        playlist: _calmPlaylist, // calm playlist, but music is already playing
      );
      addTearDown(container.dispose);

      await container.read(chatNotifierProvider.notifier).sendMessage('Hey');

      final messages = fakeClient.capturedMessages ?? [];
      final systemMessages =
          messages.where((m) => m['role'] == 'system').toList();

      for (final msg in systemMessages) {
        expect(
          (msg['content'] ?? '').contains('music'),
          isFalse,
          reason: 'Music hint should not be injected when a track is playing',
        );
      }
    });

    test('does not append hint when mood is not calm', () async {
      final fakeClient = _FakeHermesClient();
      final container = _buildContainer(
        fakeClient: fakeClient,
        notifierFactory: _EmptyMusicNotifier.new,
        playlist: null, // no playlist = mood not calm
      );
      addTearDown(container.dispose);

      await container.read(chatNotifierProvider.notifier).sendMessage('Hey');

      final messages = fakeClient.capturedMessages ?? [];
      final systemMessages =
          messages.where((m) => m['role'] == 'system').toList();

      for (final msg in systemMessages) {
        expect(
          (msg['content'] ?? '').contains('music'),
          isFalse,
          reason: 'Music hint should not be injected when mood is not calm',
        );
      }
    });
  });
}
