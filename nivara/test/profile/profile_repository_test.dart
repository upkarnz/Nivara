import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/shared/models/user_profile.dart';

void main() {
  test('UserProfile.empty has blank fields', () {
    final p = UserProfile.empty();
    expect(p.name, isEmpty);
    expect(p.language, equals('en'));
  });

  test('AssistantConfig.defaults uses Rocky as name', () {
    final a = AssistantConfig.defaults();
    expect(a.name, equals('Rocky'));
    expect(a.voice, equals('neutral'));
  });
}
