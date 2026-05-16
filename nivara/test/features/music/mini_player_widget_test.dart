import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';
import 'package:nivara/features/music/presentation/widgets/mini_player_widget.dart';

import 'music_player_notifier_test.mocks.dart';

const _track = MusicTrack(
  id: 'calm_01',
  title: 'Morning Mist',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 4),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/calm_01.mp3',
);

/// Notifier stub — isPlaying=true with track set.
class _PlayingNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState(
        isPlaying: true,
        currentTrack: _track,
      );
}

/// Notifier stub — isPlaying=false with track set.
class _PausedNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState(
        isPlaying: false,
        currentTrack: _track,
      );
}

/// Notifier stub — no track (initial state).
class _EmptyNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState();
}

Widget _wrap({
  required MusicPlayerNotifier Function() notifierFactory,
  required List<GoRoute> extraRoutes,
}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(
        bottomNavigationBar: MiniPlayerWidget(),
        body: SizedBox(),
      ),
    ),
    ...extraRoutes,
  ]);

  return ProviderScope(
    overrides: [
      musicServiceProvider.overrideWithValue(MockMusicService()),
      musicRepositoryProvider.overrideWithValue(MockMusicRepository()),
      musicPlayerNotifierProvider.overrideWith(notifierFactory),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    // Stub not needed — overrides replace real service.
  });

  group('MiniPlayerWidget', () {
    testWidgets('hidden (SizedBox.shrink) when no track loaded', (tester) async {
      await tester.pumpWidget(_wrap(
        notifierFactory: _EmptyNotifier.new,
        extraRoutes: [],
      ));
      await tester.pump();

      expect(find.byType(Container), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('shows track title when track loaded', (tester) async {
      await tester.pumpWidget(_wrap(
        notifierFactory: _PlayingNotifier.new,
        extraRoutes: [],
      ));
      await tester.pump();

      expect(find.text('Morning Mist'), findsOneWidget);
    });

    testWidgets('shows track artist when track loaded', (tester) async {
      await tester.pumpWidget(_wrap(
        notifierFactory: _PlayingNotifier.new,
        extraRoutes: [],
      ));
      await tester.pump();

      expect(find.text('Ambient Studio'), findsOneWidget);
    });

    testWidgets('shows pause icon when playing', (tester) async {
      await tester.pumpWidget(_wrap(
        notifierFactory: _PlayingNotifier.new,
        extraRoutes: [],
      ));
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('shows play_arrow icon when paused', (tester) async {
      await tester.pumpWidget(_wrap(
        notifierFactory: _PausedNotifier.new,
        extraRoutes: [],
      ));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('tapping bar navigates to /music', (tester) async {
      await tester.pumpWidget(_wrap(
        notifierFactory: _PlayingNotifier.new,
        extraRoutes: [
          GoRoute(
            path: '/music',
            builder: (_, __) => const Scaffold(body: Text('MusicPage')),
          ),
        ],
      ));
      await tester.pump();

      // Tap the GestureDetector wrapping the mini-player bar.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('MusicPage'), findsOneWidget);
    });
  });
}
