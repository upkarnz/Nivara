import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/music/data/music_manifest.dart';
import 'package:nivara/features/music/domain/mood_category.dart';

void main() {
  group('kMusicManifest', () {
    test('has exactly 9 tracks', () {
      expect(kMusicManifest.length, 9);
    });

    test('has 3 tracks per mood category', () {
      for (final category in MoodCategory.values) {
        final tracks = kMusicManifest.where((t) => t.moodCategory == category);
        expect(tracks.length, 3, reason: '$category should have 3 tracks');
      }
    });

    test('all tracks have non-empty assetPath', () {
      for (final track in kMusicManifest) {
        expect(track.assetPath, isNotNull);
        expect(track.assetPath, isNotEmpty);
      }
    });

    test('all track ids are unique', () {
      final ids = kMusicManifest.map((t) => t.id).toSet();
      expect(ids.length, kMusicManifest.length);
    });
  });
}
