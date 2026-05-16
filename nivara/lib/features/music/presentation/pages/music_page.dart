import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/mood_playlist_provider.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';

/// Full-screen music player page.
///
/// Shows:
/// - Album art placeholder
/// - Track title + artist
/// - Linear progress bar
/// - Prev / Play-Pause / Skip controls
/// - Playlist track list below
class MusicPage extends ConsumerWidget {
  const MusicPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerNotifierProvider);
    final notifier = ref.read(musicPlayerNotifierProvider.notifier);
    final playlistAsync = ref.watch(moodPlaylistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music'),
        actions: [
          // Mood auto-play toggle
          Row(
            children: [
              const Text('Auto'),
              Switch(
                value: state.isMoodAutoPlay,
                onChanged: notifier.setMoodAutoPlay,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ----- Player section -----
          Expanded(
            flex: 3,
            child: _PlayerSection(state: state, notifier: notifier),
          ),

          const Divider(height: 1),

          // ----- Playlist section -----
          Expanded(
            flex: 2,
            child: playlistAsync.when(
              data: (playlist) {
                if (playlist == null || playlist.tracks.isEmpty) {
                  return const Center(
                    child: Text('No playlist available for current mood.'),
                  );
                }
                return _PlaylistSection(
                  tracks: playlist.tracks,
                  currentTrack: state.currentTrack,
                  onTrackTap: notifier.play,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Could not load playlist.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player section — album art, title, artist, progress, controls
// ---------------------------------------------------------------------------

class _PlayerSection extends StatelessWidget {
  const _PlayerSection({
    required this.state,
    required this.notifier,
  });

  final MusicPlayerState state;
  final MusicPlayerNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack;
    final totalSeconds =
        track?.duration.inSeconds.toDouble().clamp(1.0, double.infinity) ?? 1.0;
    final progressSeconds = state.progress.inSeconds.toDouble();
    final progressFraction = (progressSeconds / totalSeconds).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album art placeholder
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.music_note,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          // Track title
          Text(
            track?.title ?? '—',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Artist
          Text(
            track?.artist ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Progress bar
          LinearProgressIndicator(
            value: progressFraction,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),

          const SizedBox(height: 4),

          // Duration labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.progress),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                track != null ? _formatDuration(track.duration) : '--:--',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Controls: prev / play-pause / skip
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_previous),
                onPressed: track != null ? notifier.skip : null,
                tooltip: 'Previous',
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: track != null
                    ? () {
                        if (state.isPlaying) {
                          notifier.pause();
                        } else {
                          notifier.resume();
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                ),
                child: Icon(
                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_next),
                onPressed: track != null ? notifier.skip : null,
                tooltip: 'Skip',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ---------------------------------------------------------------------------
// Playlist section — scrollable list of tracks
// ---------------------------------------------------------------------------

class _PlaylistSection extends StatelessWidget {
  const _PlaylistSection({
    required this.tracks,
    required this.currentTrack,
    required this.onTrackTap,
  });

  final List<MusicTrack> tracks;
  final MusicTrack? currentTrack;
  final void Function(MusicTrack) onTrackTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isActive = track.id == currentTrack?.id;
        return ListTile(
          leading: Icon(
            isActive ? Icons.music_note : Icons.queue_music,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            track.title,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          subtitle: Text(track.artist),
          trailing: Text(
            _formatDuration(track.duration),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          onTap: () => onTrackTap(track),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
