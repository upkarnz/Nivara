import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/hermes_client.dart';
import '../../domain/message.dart';

part 'chat_provider.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(role: MessageRole.user, content: text);
    state = [...state, userMsg];

    final placeholder = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );
    state = [...state, placeholder];

    final assistantIndex = state.length - 1;
    final hermesMessages = state
        .where((m) => !m.isStreaming)
        .map((m) => m.toHermesMap())
        .toList();

    final config = await ref.read(assistantConfigProvider.future);
    final assistantName = config?.name ?? 'Rocky';

    final client = ref.read(hermesClientProvider);
    final buffer = StringBuffer();

    await for (final chunk in client.chatStream(
      messages: hermesMessages,
      assistantName: assistantName,
    )) {
      buffer.write(chunk);
      final updated = List<ChatMessage>.from(state);
      updated[assistantIndex] = ChatMessage(
        role: MessageRole.assistant,
        content: buffer.toString(),
        isStreaming: true,
      );
      state = updated;
    }

    final finalMessages = List<ChatMessage>.from(state);
    finalMessages[assistantIndex] = ChatMessage(
      role: MessageRole.assistant,
      content: buffer.toString(),
      isStreaming: false,
    );
    state = finalMessages;
  }
}
