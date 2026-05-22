import 'package:flutter/material.dart';

import '../../../../voice/voice_state.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.voiceState = VoiceState.idle,
    this.onMicTap,
  });

  final void Function(String text) onSend;
  final bool enabled;
  final VoiceState voiceState;
  final VoidCallback? onMicTap;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final hasText = _ctrl.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    widget.onSend(text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData get _micIcon => switch (widget.voiceState) {
        VoiceState.idle => Icons.mic_none_rounded,
        VoiceState.listening => Icons.stop_circle_rounded,
        VoiceState.processing => Icons.hourglass_empty_rounded,
        VoiceState.speaking => Icons.volume_up_rounded,
      };

  Color _micColor(BuildContext context) => switch (widget.voiceState) {
        VoiceState.idle => Theme.of(context).colorScheme.onSurfaceVariant,
        VoiceState.listening => Colors.redAccent,
        VoiceState.processing => Colors.amber,
        VoiceState.speaking => Colors.green,
      };

  bool get _micEnabled =>
      widget.voiceState != VoiceState.processing && widget.onMicTap != null;

  bool get _isVoiceActive => widget.voiceState != VoiceState.idle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final micColor = _micColor(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          // ── Mic button ─────────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: _isVoiceActive
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: micColor.withValues(alpha: 0.15),
                  )
                : null,
            child: IconButton(
              icon: widget.voiceState == VoiceState.processing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: micColor,
                      ),
                    )
                  : Icon(_micIcon, color: micColor, size: 22),
              onPressed: _micEnabled ? widget.onMicTap : null,
              tooltip: switch (widget.voiceState) {
                VoiceState.idle => 'Voice input',
                VoiceState.listening => 'Stop listening',
                VoiceState.processing => 'Processing…',
                VoiceState.speaking => 'Stop speaking',
              },
            ),
          ),

          // ── Text field ─────────────────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: widget.enabled && !_isVoiceActive,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: _isVoiceActive
                    ? switch (widget.voiceState) {
                        VoiceState.listening => 'Listening…',
                        VoiceState.processing => 'Thinking…',
                        VoiceState.speaking => 'Speaking…',
                        _ => 'Message…',
                      }
                    : 'Message…',
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                border: InputBorder.none,
                filled: false,
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
            ),
          ),

          // ── Send button — only shown when there is typed text ───────────────
          if (_hasText && !_isVoiceActive)
            IconButton(
              icon: Icon(Icons.send_rounded, color: cs.primary),
              onPressed: widget.enabled ? _submit : null,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
