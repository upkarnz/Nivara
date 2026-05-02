import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_settings_provider.dart';
import 'wake_word_engine.dart';

/// Settings page for configuring the wake-word detection engine.
///
/// Presents a [RadioListTile] per [WakeWordEngine] value.
/// When [WakeWordEngine.porcupine] is selected, an additional text field
/// appears so the user can paste their Picovoice AccessKey.
class VoiceSettingsPage extends ConsumerStatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  ConsumerState<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends ConsumerState<VoiceSettingsPage> {
  late final TextEditingController _keyCtrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(voiceSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake Word Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          // Keep text-field in sync when settings load.
          if (_keyCtrl.text.isEmpty && settings.porcupineAccessKey.isNotEmpty) {
            _keyCtrl.text = settings.porcupineAccessKey;
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Wake Word Engine',
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

              // ── Porcupine AccessKey field (conditional) ───────────────────
              if (settings.engine == WakeWordEngine.porcupine)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    key: const Key('porcupine_key_field'),
                    controller: _keyCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Picovoice AccessKey',
                      hintText: 'Paste your AccessKey here',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
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
                        .setPorcupineAccessKey(_keyCtrl.text.trim()),
                    child: const Text('Save AccessKey'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
