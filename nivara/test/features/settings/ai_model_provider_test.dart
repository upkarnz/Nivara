import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('aiModelNotifierProvider defaults to gemini_flash', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(aiModelNotifierProvider.future);
    expect(value, 'gemini_flash');
  });

  test('setModel persists to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(aiModelNotifierProvider.future);
    await container.read(aiModelNotifierProvider.notifier).setModel('gemini');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_ai_model'), 'gemini');
  });

  test('aiModelNotifierProvider loads persisted value', () async {
    SharedPreferences.setMockInitialValues({'selected_ai_model': 'openai'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(aiModelNotifierProvider.future);
    expect(value, 'openai');
  });
}
