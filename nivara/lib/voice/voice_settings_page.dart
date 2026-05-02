import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tts_provider.dart';
import 'voice_settings_provider.dart';
import 'wake_word_engine.dart';

/// Settings page for configuring wake-word detection and TTS engine.
///
/// • Wake Word section: [RadioListTile] per [WakeWordEngine].
///   When [WakeWordEngine.porcupine] is selected an AccessKey field appears.
///
/// • TTS Provider section: [RadioListTile] per [TtsProvider].
///   When [TtsProvider.elevenLabs] is selected an API key field appears.
class VoiceSettingsPage extends ConsumerStatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  ConsumerState<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends ConsumerState<VoiceSettingsPage> {
  late final TextEditingController _porcupineCtrl;
  late final TextEditingController _elevenLabsCtrl;
  bool _obscurePorcupine = true;
  bool _obscureElevenLabs = true;

  @override
  void initState() {
    super.initState();
    _porcupineCtrl = TextEditingController();
    _elevenLabsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _porcupineCtrl.dispose();
    _elevenLabsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(voiceSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          // Keep text fields in sync when settings load.
          if (_porcupineCtrl.text.isEmpty &&
              settings.porcupineAccessKey.isNotEmpty) {
            _porcupineCtrl.text = settings.porcupineAccessKey;
          }
          if (_elevenLabsCtrl.text.isEmpty &&
              settings.elevenLabsApiKey.isNotEmpty) {
            _elevenLabsCtrl.text = settings.elevenLabsApiKey;
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // ── Wake Word section header ────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'WAKE WORD ENGINE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // ── STT option ──────────────────────────────────────────────
              RadioListTile<WakeWordEngine>(
                value: WakeWordEngine.stt,
                groupValue: settings.engine,
                title: const Text('Built-in (speech recognition)'),
                subtitle: const Text(
                  'No API key required. Uses on-device speech recognition '
                  'to listen for the wake word "Nivara".',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(voiceSettingsProvider.notifier)
                        .setEngine(v);
                  }
                },
              ),

              // ── Porcupine option ─────────────────────────────────────────
              RadioListTile<WakeWordEngine>(
                value: WakeWordEngine.porcupine,
                groupValue: settings.engine,
                title: const Text('Porcupine (custom wake word)'),
                subtitle: const Text(
                  'High-accuracy, always-on wake word detection by Picovoice. '
                  'Requires a free AccessKey from console.picovoice.ai.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(voiceSettingsProvider.notifier)
                        .setEngine(v);
                  }
                },
              ),

              // ── Porcupine AccessKey field (conditional) ──────────────────
              if (settings.engine == WakeWordEngine.porcupine)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    key: const Key('porcupine_key_field'),
                    controller: _porcupineCtrl,
                    obscureText: _obscurePorcupine,
                    decoration: InputDecoration(
                      labelText: 'Picovoice AccessKey',
                      hintText: 'Paste your AccessKey here',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePorcupine
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePorcupine = !_obscurePorcupine),
                      ),
                    ),
                    onSubmitted: (key) => ref
                        .read(voiceSettingsProvider.notifier)
                        .setPorcupineAccessKey(key.trim()),
                    onEditingComplete: () {},
                  ),
                ),

              if (settings.engine == WakeWordEngine.porcupine)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(voiceSettingsProvider.notifier)
                        .setPorcupineAccessKey(_porcupineCtrl.text.trim()),
                    child: const Text('Save AccessKey'),
                  ),
                ),

              const Divider(height: 32),

              // ── TTS Provider section header ──────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'TEXT-TO-SPEECH ENGINE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // ── flutter_tts option ───────────────────────────────────────
              RadioListTile<TtsProvider>(
                value: TtsProvider.flutterTts,
                groupValue: settings.ttsProvider,
                title: const Text('Built-in TTS'),
                subtitle: const Text(
                  'No API key required. Uses on-device text-to-speech.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(voiceSettingsProvider.notifier)
                        .setTtsProvider(v);
                  }
                },
              ),

              // ── ElevenLabs option ────────────────────────────────────────
              RadioListTile<TtsProvider>(
                value: TtsProvider.elevenLabs,
                groupValue: settings.ttsProvider,
                title: const Text('ElevenLabs (cloud)'),
                subtitle: const Text(
                  'High-quality AI voice synthesis. Requires a free API key '
                  'from elevenlabs.io.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(voiceSettingsProvider.notifier)
                        .setTtsProvider(v);
                  }
                },
              ),

              // ── ElevenLabs API key field (conditional) ───────────────────
              if (settings.ttsProvider == TtsProvider.elevenLabs)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    key: const Key('elevenlabs_key_field'),
                    controller: _elevenLabsCtrl,
                    obscureText: _obscureElevenLabs,
                    decoration: InputDecoration(
                      labelText: 'ElevenLabs API Key',
                      hintText: 'Paste your API key here',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureElevenLabs
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                            () => _obscureElevenLabs = !_obscureElevenLabs),
                      ),
                    ),
                    onSubmitted: (key) => ref
                        .read(voiceSettingsProvider.notifier)
                        .setElevenLabsApiKey(key.trim()),
                    onEditingComplete: () {},
                  ),
                ),

              if (settings.ttsProvider == TtsProvider.elevenLabs)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(voiceSettingsProvider.notifier)
                        .setElevenLabsApiKey(_elevenLabsCtrl.text.trim()),
                    child: const Text('Save API Key'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
