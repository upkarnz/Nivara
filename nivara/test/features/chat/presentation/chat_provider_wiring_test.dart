// nivara/test/features/chat/presentation/chat_provider_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'selected_ai_model': 'gemini'});
  });

  test('aiModelNotifierProvider returns gemini when set', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final model = await container.read(aiModelNotifierProvider.future);
    expect(model, 'gemini');
  });
}
