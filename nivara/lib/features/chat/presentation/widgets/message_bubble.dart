import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../domain/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 4,
              bottom: message.scheduledEvent != null ? 4 : 4,
              left: isUser ? 64 : 0,
              right: isUser ? 0 : 64,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: message.isStreaming
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: _MessageContent(
                          content: message.content,
                          isUser: isUser,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : _MessageContent(
                    content: message.content,
                    isUser: isUser,
                  ),
          ),
          if (message.scheduledEvent != null)
            _EventCard(event: message.scheduledEvent!),
        ],
      ),
    );
  }
}

/// Renders user messages as plain text, assistant messages as markdown.
class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.content, required this.isUser});

  final String content;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final textColor = isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    if (isUser) {
      return Text(content, style: TextStyle(color: textColor));
    }

    // Assistant messages: render markdown so bold, lists, etc. display correctly.
    return MarkdownBody(
      data: content,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(color: textColor, fontSize: 14),
        strong: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
        em: TextStyle(color: textColor, fontStyle: FontStyle.italic, fontSize: 14),
        listBullet: TextStyle(color: textColor, fontSize: 14),
        code: TextStyle(
          color: textColor,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        blockquote: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14),
        h1: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        h2: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
        h3: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final Map<String, dynamic> event;

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, $h:$m';
    } on FormatException {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? 'Event';
    final start = _formatTime(event['start'] as String?);
    final end = _formatTime(event['end'] as String?);

    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event, color: cs.primary, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (start.isNotEmpty)
                Text(
                  end.isNotEmpty ? '$start – $end' : start,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
