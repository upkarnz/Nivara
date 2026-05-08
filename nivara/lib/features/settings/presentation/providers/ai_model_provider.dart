import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'selected_ai_model';
const _defaultModel = 'claude';

class AiModelNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey) ?? _defaultModel;
  }

  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, model);
    state = AsyncData(model);
  }
}

final aiModelNotifierProvider =
    AsyncNotifierProvider<AiModelNotifier, String>(AiModelNotifier.new);
