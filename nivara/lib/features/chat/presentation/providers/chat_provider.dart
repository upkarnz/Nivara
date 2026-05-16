import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../mood/domain/mood_entry.dart';
import '../../../mood/presentation/providers/mood_provider.dart';
import '../../../music/domain/mood_category.dart';
import '../../../music/presentation/providers/mood_playlist_provider.dart';
import '../../../music/presentation/providers/music_player_notifier.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../planner/data/firestore_calendar_repository.dart';
import '../../../planner/domain/event.dart';
import '../../../settings/presentation/providers/ai_model_provider.dart';
import '../../../subscription/data/quota_repository.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../data/hermes_client.dart';
import '../../domain/event_parser.dart';
import '../../domain/message.dart';

part 'chat_provider.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    // ── Quota check ──────────────────────────────────────────────────────────
    // Use .future so we wait for the first stream emission in tests and prod.
    QuotaState? quotaState;
    try {
      quotaState = await ref.read(quotaProvider.future);
    } catch (_) {
      // If quota state is unavailable, allow the message through.
    }
    if (quotaState != null && quotaState.exhausted) {
      // UI (ChatPage) shows PaywallSheet. Notifier returns early.
      return;
    }
    final isGrace = quotaState?.inGrace == true;

    final userMsg = ChatMessage(role: MessageRole.user, content: text);
    state = [...state, userMsg];

    const placeholder = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );
    state = [...state, placeholder];

    final assistantIndex = state.length - 1;

    // Build conversation history (exclude the streaming placeholder).
    final baseMessages = state
        .where((m) => !m.isStreaming)
        .map((m) => m.toHermesMap())
        .toList();

    // Silently read tone hint — any failure defaults to null (no injection).
    String? toneHint;
    try {
      toneHint = await ref.read(moodToneProvider.future);
    } catch (_) {
      // Degrade gracefully: use default Nivara tone.
    }

    // Check whether to append a proactive music suggestion hint.
    // Only injected when: mood playlist is calm AND no track is currently playing.
    String? musicSuggestionHint;
    try {
      final moodPlaylist = await ref.read(moodPlaylistProvider.future);
      final isCalm = moodPlaylist?.moodCategory == MoodCategory.calm;
      final isPlaying =
          ref.read(musicPlayerNotifierProvider).currentTrack != null;
      if (isCalm && !isPlaying) {
        musicSuggestionHint =
            'If contextually appropriate, suggest the user play some music.';
      }
    } catch (_) {
      // Non-critical — degrade gracefully.
    }

    // Prepend system messages only when hints are available.
    // Hints are never stored in state and never shown in the UI.
    final hermesMessages = [
      if (toneHint != null) {'role': 'system', 'content': toneHint},
      if (musicSuggestionHint != null)
        {'role': 'system', 'content': musicSuggestionHint},
      ...baseMessages,
    ];

    final config = await ref.read(assistantConfigProvider.future);
    final assistantName = config?.name ?? 'Rocky';

    final client = ref.read(hermesClientProvider);
    final aiModel = await ref
        .read(aiModelNotifierProvider.future)
        .catchError((_) => 'gemini_flash');
    final buffer = StringBuffer();
    var moodSaved = false;

    await for (final chunk in client.chatStream(
      messages: hermesMessages,
      assistantName: assistantName,
      aiModel: aiModel,
    )) {
      switch (chunk) {
        case TextChunk(:final text):
          buffer.write(text);
          final updated = List<ChatMessage>.from(state);
          updated[assistantIndex] = ChatMessage(
            role: MessageRole.assistant,
            content: buffer.toString(),
            isStreaming: true,
          );
          state = updated;
        case MoodChunk(:final score, :final label):
          if (!moodSaved) {
            moodSaved = true;
            unawaited(_saveMoodPassive(score, label));
          }
        case DoneChunk():
          break;
      }
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

    // ── Quota tracking ────────────────────────────────────────────────────────
    try {
      final repo = ref.read(quotaRepositoryProvider);
      if (isGrace) {
        await repo.incrementGrace();
      } else {
        await repo.incrementMessage();
      }
    } catch (_) {
      // Non-critical: quota write failure (e.g. no auth) does not block chat.
    }
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

  Future<void> _saveMoodPassive(int score, String label) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entry = MoodEntry(
        date: today,
        score: score,
        label: label,
        source: MoodSource.passive,
      );
      final repo = ref.read(moodRepositoryProvider);
      await repo.save(entry);
      ref.invalidate(weekMoodProvider);
      ref.invalidate(todayMoodProvider);
    } on Exception {
      // Non-critical: mood failure must not crash chat.
    }
  }
}
