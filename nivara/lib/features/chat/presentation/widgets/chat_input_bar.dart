import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.onSend, this.enabled = true});

  final void Function(String text) onSend;
  final bool enabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A24),
        border: Border(top: BorderSide(color: Color(0xFF2D2D3D))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
            onPressed: widget.enabled ? _submit : null,
          ),
        ],
      ),
    );
  }
}
