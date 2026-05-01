import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/domain/message.dart';

void main() {
  test('ChatMessage serialises to Hermes format', () {
    const msg = ChatMessage(role: MessageRole.user, content: 'Hello');
    final map = msg.toHermesMap();
    expect(map['role'], equals('user'));
    expect(map['content'], equals('Hello'));
  });

  test('ChatMessage.assistant has correct role', () {
    const msg = ChatMessage(role: MessageRole.assistant, content: 'Hi!');
    expect(msg.isUser, isFalse);
  });
}
