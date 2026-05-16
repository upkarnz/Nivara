import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/pages/music_page.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';

import 'music_player_notifier_test.mocks.dart';

const _calm = MusicTrack(
  id: 'calm_01',
  title: 'Morning Mist',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 4),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/calm_01.mp3',
);

const _neutral = MusicTrack(
  id: 'neutral_01',
  title: 'Coffee Shop Beats',
  artist: 'Lo-Fi Lab',
  duration: Duration(minutes: 3),
  moodCategory: MoodCategory.neutral,
  assetPath: 'assets/music/neutral/neutral_01.mp3',
);

const _playlist = MusicPlaylist(
  moodCategory: MoodCategory.calm,
  tracks: [_calm, _neutral],
);

class _PlayingNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState(
        isPlaying: true,
        currentTrack: _calm,
        currentPlaylist: _playlist,
        progress: Duration(seconds: 30),
      );
}

class _EmptyNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState();
}

Widget _wrap({
  required MusicPlayerNotifier Function() notifierFactory,
  MusicPlaylist? playlist,
}) {
  final mockRepo = MockMusicRepository();
  if (playlist != null) {
    when(mockRepo.getPlaylistForMood(any)).thenAnswer((_) async => playlist);
  }

  return ProviderScope(
    overrides: [
      musicServiceProvider.overrideWithValue(MockMusicService()),
      musicRepositoryProvider.overrideWithValue(mockRepo),
      musicPlayerNotifierProvider.overrideWith(notifierFactory),
      weekMoodProvider.overrideWith((_) async => <MoodEntry?>[]),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const MusicPage(),
        ),
      ]),
    ),
  );
}

void main() {
  group('MusicPage', () {
    testWidgets('shows AppBar with title "Music"', (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _EmptyNotifier.new));
      await tester.pump();

      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('shows em-dash when no track loaded', (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _EmptyNotifier.new));
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('shows track title when playing', (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _PlayingNotifier.new));
      await tester.pump();

      expect(find.text('Morning Mist'), findsWidgets);
    });

    testWidgets('shows track artist when playing', (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _PlayingNotifier.new));
      await tester.pump();

      expect(find.text('Ambient Studio'), findsWidgets);
    });

    testWidgets('shows pause icon when playing', (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _PlayingNotifier.new));
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('shows play_arrow icon when not playing', (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _EmptyNotifier.new));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _PlayingNotifier.new));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('no playlist message shown when moodPlaylistProvider returns null',
        (tester) async {
      await tester.pumpWidget(_wrap(notifierFactory: _EmptyNotifier.new));
      await tester.pumpAndSettle();

      expect(
        find.text('No playlist available for current mood.'),
        findsOneWidget,
      );
    });
  });
}
