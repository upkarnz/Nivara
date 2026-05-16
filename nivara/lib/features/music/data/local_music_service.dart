import 'package:just_audio/just_audio.dart';
import 'package:nivara/features/music/domain/music_service.dart';
import 'package:nivara/features/music/domain/music_track.dart';

class LocalMusicService implements MusicService {
  final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Future<void> play(MusicTrack track) async {
    if (track.assetPath != null) {
      await _player.setAudioSource(AudioSource.asset(track.assetPath!));
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> skip() => _player.stop();

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  Future<void> dispose() => _player.dispose();
}
