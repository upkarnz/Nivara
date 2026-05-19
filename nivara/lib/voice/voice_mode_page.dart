import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_provider.dart';
import 'voice_state.dart';

/// Full-screen voice mode overlay with animated waveform and text fallback.
class VoiceModePage extends ConsumerStatefulWidget {
  const VoiceModePage({super.key});

  @override
  ConsumerState<VoiceModePage> createState() => _VoiceModePageState();
}

class _VoiceModePageState extends ConsumerState<VoiceModePage>
    with TickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _pulseCtrl;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _focusNode.unfocus();
    ref.read(voiceProvider.notifier).sendTextMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);
    final sttReady = notifier.isSttReady;
    final isActive = voiceState == VoiceState.listening ||
        voiceState == VoiceState.speaking;
    final isBusy = voiceState == VoiceState.listening ||
        voiceState == VoiceState.processing ||
        voiceState == VoiceState.speaking;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white70, size: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    _stateLabel(voiceState),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Waveform area ────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_waveCtrl, _pulseCtrl]),
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(280, 120),
                          painter: _WaveformPainter(
                            progress: _waveCtrl.value,
                            pulse: _pulseCtrl.value,
                            active: isActive,
                            color: _stateColor(voiceState),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // STT unavailable notice
                    if (!sttReady) ...[
                      const Icon(Icons.mic_off, color: Colors.white38, size: 20),
                      const SizedBox(height: 6),
                      const Text(
                        'Microphone unavailable on this device.\nUse the text field below.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── State description ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _stateDescription(voiceState, sttReady: sttReady),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

            // ── Mic button (only when STT available) ─────────────────────────
            if (sttReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final scale = isActive ? 1.0 + 0.08 * _pulseCtrl.value : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: GestureDetector(
                    onTap: () => _handleTap(voiceState, notifier),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _stateColor(voiceState),
                        boxShadow: [
                          BoxShadow(
                            color: _stateColor(voiceState).withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _stateIcon(voiceState),
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Text input row (always visible) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      enabled: !isBusy,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendText(),
                      decoration: InputDecoration(
                        hintText: sttReady
                            ? 'Or type a message…'
                            : 'Type a message…',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1E1E2E),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: isBusy ? null : _sendText,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBusy
                            ? Colors.white12
                            : const Color(0xFF6366F1),
                      ),
                      child: isBusy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            )
                          : const Icon(Icons.send,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(VoiceState state, VoiceNotifier notifier) {
    switch (state) {
      case VoiceState.idle:
        notifier.startListening();
      case VoiceState.listening:
      case VoiceState.speaking:
        notifier.stopAll();
      case VoiceState.processing:
        break;
    }
  }

  Color _stateColor(VoiceState s) => switch (s) {
        VoiceState.idle => const Color(0xFF6366F1),
        VoiceState.listening => Colors.red,
        VoiceState.processing => Colors.amber,
        VoiceState.speaking => Colors.green,
      };

  IconData _stateIcon(VoiceState s) => switch (s) {
        VoiceState.idle => Icons.mic,
        VoiceState.listening => Icons.stop,
        VoiceState.processing => Icons.hourglass_empty,
        VoiceState.speaking => Icons.volume_up,
      };

  String _stateLabel(VoiceState s) => switch (s) {
        VoiceState.idle => 'Voice Mode',
        VoiceState.listening => 'Listening…',
        VoiceState.processing => 'Thinking…',
        VoiceState.speaking => 'Speaking…',
      };

  String _stateDescription(VoiceState s, {required bool sttReady}) {
    if (!sttReady) {
      return switch (s) {
        VoiceState.idle => 'Type below and tap Send',
        VoiceState.processing => 'Processing your message…',
        VoiceState.speaking => 'Speaking response…',
        VoiceState.listening => 'Listening…',
      };
    }
    return switch (s) {
      VoiceState.idle => 'Tap the mic to start',
      VoiceState.listening => 'Speak now',
      VoiceState.processing => 'Processing your message',
      VoiceState.speaking => 'Tap to stop',
    };
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.progress,
    required this.pulse,
    required this.active,
    required this.color,
  });

  final double progress;
  final double pulse;
  final bool active;
  final Color color;

  static const _barCount = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final barWidth = size.width / (_barCount * 1.6);
    final spacing = (size.width - barWidth * _barCount) / (_barCount - 1);
    final centerY = size.height / 2;
    final maxAmp = size.height / 2 * 0.9;

    for (var i = 0; i < _barCount; i++) {
      final x = i * (barWidth + spacing) + barWidth / 2;
      final phase = progress * 2 * math.pi + i * 0.4;
      final envelope = math.sin(i / (_barCount - 1) * math.pi);

      double amp;
      if (active) {
        amp = (math.sin(phase) * 0.5 + 0.5) * envelope * maxAmp;
        amp = amp * (0.6 + 0.4 * pulse);
      } else {
        amp = envelope * maxAmp * 0.12;
      }

      final opacity = active ? (0.5 + 0.5 * envelope) : 0.25;
      paint.color = color.withValues(alpha: opacity);

      canvas.drawLine(
        Offset(x, centerY - amp.clamp(4, maxAmp)),
        Offset(x, centerY + amp.clamp(4, maxAmp)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.active != active ||
      old.color != color;
}
