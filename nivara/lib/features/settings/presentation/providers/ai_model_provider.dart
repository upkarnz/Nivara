import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'selected_ai_model';

/// Canonical model IDs used throughout the app.
const kModelGeminiFlash = 'gemini_flash';
const kModelGpt4oMini = 'gpt4o_mini';
const kModelClaudeHaiku = 'claude_haiku';
const kModelClaudeSonnet = 'claude_sonnet';
const kModelGpt4o = 'gpt4o';

/// The default model ID — Gemini Flash gives the highest message quota.
const kDefaultModel = kModelGeminiFlash;

class AiModelNotifier extends AsyncNotifier<String> {
  late SharedPreferences _prefs;

  @override
  Future<String> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _prefs.getString(_prefsKey) ?? kDefaultModel;
  }

  Future<void> setModel(String model) async {
    await _prefs.setString(_prefsKey, model);
    state = AsyncData(model);
  }
}

final aiModelNotifierProvider =
    AsyncNotifierProvider<AiModelNotifier, String>(AiModelNotifier.new);
