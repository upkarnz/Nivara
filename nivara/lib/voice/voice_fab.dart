import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_provider.dart';
import 'voice_state.dart';

/// A floating action button that reflects the current [VoiceState].
///
/// - [VoiceState.idle]       → indigo mic icon  (tap to start listening)
/// - [VoiceState.listening]  → red stop icon    (tap to cancel)
/// - [VoiceState.processing] → amber hourglass  (disabled)
/// - [VoiceState.speaking]   → green speaker    (tap to stop TTS)
class VoiceFab extends ConsumerWidget {
  const VoiceFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);

    return FloatingActionButton(
      backgroundColor: _backgroundColor(voiceState),
      onPressed: _onPressed(voiceState, notifier),
      tooltip: _tooltip(voiceState),
      child: Icon(_icon(voiceState), color: Colors.white),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _backgroundColor(VoiceState s) => switch (s) {
        VoiceState.idle => Colors.indigo,
        VoiceState.listening => Colors.red,
        VoiceState.processing => Colors.amber,
        VoiceState.speaking => Colors.green,
      };

  IconData _icon(VoiceState s) => switch (s) {
        VoiceState.idle => Icons.mic,
        VoiceState.listening => Icons.stop,
        VoiceState.processing => Icons.hourglass_empty,
        VoiceState.speaking => Icons.volume_up,
      };

  String _tooltip(VoiceState s) => switch (s) {
        VoiceState.idle => 'Start listening',
        VoiceState.listening => 'Stop listening',
        VoiceState.processing => 'Processing…',
        VoiceState.speaking => 'Stop speaking',
      };

  VoidCallback? _onPressed(VoiceState s, VoiceNotifier notifier) =>
      switch (s) {
        VoiceState.idle => notifier.startListening,
        VoiceState.listening => notifier.stopAll,
        VoiceState.processing => null, // disabled while processing
        VoiceState.speaking => notifier.stopAll,
      };
}
