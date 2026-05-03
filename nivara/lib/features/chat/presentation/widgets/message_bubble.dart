import 'package:flutter/material.dart';
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
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: message.isStreaming
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.content,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  )
                : Text(
                    message.content,
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
          if (message.scheduledEvent != null)
            _EventCard(event: message.scheduledEvent!),
        ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event, color: Color(0xFF6366F1), size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (start.isNotEmpty)
                Text(
                  end.isNotEmpty ? '$start – $end' : start,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
