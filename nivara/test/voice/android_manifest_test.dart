import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AndroidManifest declares RECORD_AUDIO permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
  });
}
