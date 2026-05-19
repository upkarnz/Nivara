import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'selected_ai_model';

/// Canonical model IDs used throughout the app.
const kModelGroq = 'groq';
const kModelGeminiFlash = 'gemini_flash';
const kModelGpt4oMini = 'gpt4o_mini';
const kModelClaudeHaiku = 'claude_haiku';
const kModelClaudeSonnet = 'claude_sonnet';
const kModelGpt4o = 'gpt4o';

/// The default model ID — Claude Haiku is the reliable default.
const kDefaultModel = kModelClaudeHaiku;

class AiModelNotifier extends AsyncNotifier<String> {
  late SharedPreferences _prefs;

  @override
  Future<String> build() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getString(_prefsKey) ?? kDefaultModel;
    // Migrate: groq is not configured on the backend — fall back to default.
    if (stored == kModelGroq) {
      await _prefs.setString(_prefsKey, kDefaultModel);
      return kDefaultModel;
    }
    return stored;
  }

  Future<void> setModel(String model) async {
    await _prefs.setString(_prefsKey, model);
    state = AsyncData(model);
  }
}

final aiModelNotifierProvider =
    AsyncNotifierProvider<AiModelNotifier, String>(AiModelNotifier.new);
