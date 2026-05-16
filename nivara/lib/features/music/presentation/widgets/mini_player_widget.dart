import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';

/// Persistent 56 dp mini-player bar.
/// Hidden (zero height) when no track is loaded.
/// Shows track title + artist + play/pause button.
/// Tapping the bar navigates to the full MusicPage.
class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key});

  static const double _barHeight = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerNotifierProvider);

    // Hidden when nothing is playing.
    if (state.currentTrack == null) {
      return const SizedBox.shrink();
    }

    final track = state.currentTrack!;
    final notifier = ref.read(musicPlayerNotifierProvider.notifier);

    return GestureDetector(
      onTap: () => context.push('/music'),
      child: Container(
        height: _barHeight,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Track info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Play / Pause button
            IconButton(
              icon: Icon(
                state.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () {
                if (state.isPlaying) {
                  notifier.pause();
                } else {
                  notifier.resume();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
