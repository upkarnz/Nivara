import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/voice/music_command.dart';

void main() {
  group('matchMusicCommand', () {
    test('play music → MusicCommand.play', () {
      expect(matchMusicCommand('play music'), MusicCommand.play);
      expect(matchMusicCommand('start music'), MusicCommand.play);
      expect(matchMusicCommand('PLAY MUSIC'), MusicCommand.play);
    });

    test('pause / stop music → MusicCommand.pause', () {
      expect(matchMusicCommand('pause'), MusicCommand.pause);
      expect(matchMusicCommand('stop music'), MusicCommand.pause);
    });

    test('resume / continue → MusicCommand.resume', () {
      expect(matchMusicCommand('resume'), MusicCommand.resume);
      expect(matchMusicCommand('continue playing'), MusicCommand.resume);
    });

    test('skip / next song → MusicCommand.skip', () {
      expect(matchMusicCommand('skip'), MusicCommand.skip);
      expect(matchMusicCommand('next song'), MusicCommand.skip);
    });

    test('turn off music → MusicCommand.stop', () {
      expect(matchMusicCommand('turn off music'), MusicCommand.stop);
    });

    test('calmer / relaxing → MusicCommand.playCalmCategory', () {
      expect(matchMusicCommand('play something calmer'), MusicCommand.playCalmCategory);
      expect(matchMusicCommand('something relaxing'), MusicCommand.playCalmCategory);
      expect(matchMusicCommand('calm down'), MusicCommand.playCalmCategory);
    });

    test('upbeat / energize → MusicCommand.playEnergizedCategory', () {
      expect(matchMusicCommand('play something upbeat'), MusicCommand.playEnergizedCategory);
      expect(matchMusicCommand('energize me'), MusicCommand.playEnergizedCategory);
    });

    test('unrecognised utterance returns null', () {
      expect(matchMusicCommand('what is the weather'), isNull);
      expect(matchMusicCommand('set a timer'), isNull);
      expect(matchMusicCommand(''), isNull);
    });
  });
}
