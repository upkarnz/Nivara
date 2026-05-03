import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../planner/data/firestore_calendar_repository.dart';
import '../../../planner/domain/event.dart';
import '../../data/hermes_client.dart';
import '../../domain/event_parser.dart';
import '../../domain/message.dart';

part 'chat_provider.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(role: MessageRole.user, content: text);
    state = [...state, userMsg];

    const placeholder = ChatMessage(
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

    final finalContent = buffer.toString();
    final eventMap = parseScheduledEvent(finalContent);

    Event? createdEvent;
    if (eventMap != null) {
      createdEvent = await _persistEvent(eventMap);
    }

    final finalMessages = List<ChatMessage>.from(state);
    finalMessages[assistantIndex] = ChatMessage(
      role: MessageRole.assistant,
      content: finalContent,
      isStreaming: false,
      scheduledEvent: createdEvent != null ? eventMap : null,
    );
    state = finalMessages;
  }

  Future<Event?> _persistEvent(Map<String, dynamic> eventMap) async {
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return null;

      final title = eventMap['title'] as String? ?? 'Event';
      final startStr = eventMap['start'] as String?;
      final endStr = eventMap['end'] as String?;
      if (startStr == null || endStr == null) return null;

      final startTime = DateTime.parse(startStr);
      final endTime = DateTime.parse(endStr);
      final now = DateTime.now();

      final event = Event(
        id: '',
        userId: user.uid,
        title: title,
        startTime: startTime,
        endTime: endTime,
        source: EventSource.local,
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(firestoreCalendarRepositoryProvider);
      return await repo.createEvent(event);
    } on Exception {
      return null;
    }
  }
}
