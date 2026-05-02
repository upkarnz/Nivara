import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Info.plist declares microphone and speech recognition descriptions', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSMicrophoneUsageDescription'));
    expect(plist, contains('NSSpeechRecognitionUsageDescription'));
  });
}
