import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';

void main() {
  group('parseSseData', () {
    test('returns DoneChunk for [DONE]', () {
      expect(parseSseData('[DONE]'), isA<DoneChunk>());
    });

    test('returns MoodChunk for valid __MOOD__ event', () {
      final chunk = parseSseData('__MOOD__{"score":3,"label":"neutral"}');
      expect(chunk, isA<MoodChunk>());
      final mood = chunk as MoodChunk;
      expect(mood.score, 3);
      expect(mood.label, 'neutral');
    });

    test('returns TextChunk for __MOOD__ with invalid JSON', () {
      final chunk = parseSseData('__MOOD__not-json');
      expect(chunk, isA<TextChunk>());
    });

    test('returns TextChunk for __MOOD__ with out-of-range score', () {
      final chunk = parseSseData('__MOOD__{"score":6,"label":"amazing"}');
      expect(chunk, isA<TextChunk>());
    });

    test('returns TextChunk for normal text', () {
      final chunk = parseSseData('Hello world');
      expect(chunk, isA<TextChunk>());
      expect((chunk as TextChunk).text, 'Hello world');
    });
  });
}
