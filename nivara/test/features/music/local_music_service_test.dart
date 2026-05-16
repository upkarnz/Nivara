import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/music/data/local_music_service.dart';
import 'package:nivara/features/music/domain/music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalMusicService', () {
    test('implements MusicService', () {
      final service = LocalMusicService();
      expect(service, isA<MusicService>());
      service.dispose();
    });

    test('exposes positionStream', () {
      final service = LocalMusicService();
      expect(service.positionStream, isNotNull);
      service.dispose();
    });

    test('exposes playerStateStream', () {
      final service = LocalMusicService();
      expect(service.playerStateStream, isNotNull);
      service.dispose();
    });
  });
}
