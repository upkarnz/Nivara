enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  final MessageRole role;
  final String content;
  final bool isStreaming;

  bool get isUser => role == MessageRole.user;

  Map<String, String> toHermesMap() => {
        'role': role.name,
        'content': content,
      };

  ChatMessage copyWith({String? content, bool? isStreaming}) => ChatMessage(
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}
