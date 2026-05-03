enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.scheduledEvent,
  });

  final MessageRole role;
  final String content;
  final bool isStreaming;

  // Parsed schedule_event map when the assistant schedules an event.
  final Map<String, dynamic>? scheduledEvent;

  bool get isUser => role == MessageRole.user;

  Map<String, String> toHermesMap() => {
        'role': role.name,
        'content': content,
      };

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    Map<String, dynamic>? scheduledEvent,
  }) =>
      ChatMessage(
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        scheduledEvent: scheduledEvent ?? this.scheduledEvent,
      );
}
