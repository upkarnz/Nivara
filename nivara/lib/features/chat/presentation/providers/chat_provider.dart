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
import '../../../planner/data/google_calendar_repository.dart';
import '../../../planner/domain/event.dart';
import '../../../planner/presentation/providers/planner_provider.dart' show mergeEvents, plannerNotifierProvider;
import '../../../settings/presentation/providers/ai_model_provider.dart';
import '../../../subscription/data/quota_repository.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../memory/domain/memory.dart';
import '../../../memory/presentation/providers/memory_provider.dart';
import '../../../memory/presentation/providers/memobase_provider.dart';
import '../../data/hermes_client.dart';
import '../../domain/event_parser.dart' show parseScheduledEventFull;
import '../../domain/message.dart';

part 'chat_provider.g.dart';

@Riverpod(keepAlive: true)
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

    // Inject calendar events ONLY when the user's message is about their
    // schedule. Injecting on every message causes the AI to proactively
    // mention appointments during unrelated conversations.
    String? calendarContext;
    if (!_queryNeedsCalendar(text)) {
      // Not a schedule-related query — skip the expensive calendar fetch.
    } else
    try {
      final now = DateTime.now();
      // Wide window matching PlannerNotifier so all visible events are included.
      // 800 days back catches events saved with wrong years; 365 forward covers
      // a full year of upcoming events.
      final from = now.subtract(const Duration(days: 800));
      final to = now.add(const Duration(days: 365));

      // Fetch Firestore events.
      final calRepo = ref.read(firestoreCalendarRepositoryProvider);
      final firestoreEvents = await calRepo.watchEvents(from: from, to: to).first;

      // Also fetch Google Calendar events if connected — same merge as PlannerNotifier.
      List<Event> gcalEvents = [];
      try {
        final gcalRepo = ref.read(googleCalendarRepositoryProvider);
        final connected = await gcalRepo.isConnected();
        // ignore: avoid_print
        print('[CHAT] gcal isConnected=$connected');
        if (connected) {
          gcalEvents = await gcalRepo.fetchEvents(from: from, to: to);
        }
      } catch (e) {
        // ignore: avoid_print
        print('[CHAT] gcal error: $e');
        // GCal unavailable — use Firestore only.
      }

      final events = mergeEvents(firestoreEvents, gcalEvents);
      // ignore: avoid_print
      print('[CHAT] fetched ${events.length} calendar events for context (firestore=${firestoreEvents.length} gcal=${gcalEvents.length})');
      if (events.isNotEmpty) {
        String fmtDate(DateTime dt) =>
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';
        final lines = events.map((e) {
          final loc = e.location != null ? ' @ ${e.location}' : '';
          final desc = e.description != null ? ' — ${e.description}' : '';
          final past = e.endTime.isBefore(now) ? ' [past]' : '';
          return '- ${fmtDate(e.startTime)}  ${e.title}$loc$desc$past';
        }).join('\n');
        final today =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        calendarContext =
            'CALENDAR DATA (respond to schedule questions only):\n'
            'Today is $today.\n\n'
            'USER\'S CALENDAR EVENTS:\n$lines\n\n'
            'RULES: (1) Only reference this calendar data if the user is '
            'directly asking about their schedule, appointments, or events. '
            '(2) Do NOT proactively bring up calendar events during unrelated '
            'conversations — e.g. if the user is discussing a purchase, a '
            'relationship, or any non-schedule topic, stay on that topic. '
            '(3) Events marked [past] have already occurred.';
        // ignore: avoid_print
        print('[CHAT] injecting ${events.length} calendar events as context');
      } else {
        // Still inject today's date even when calendar is empty so the AI
        // knows what day it is.
        final today =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        calendarContext = 'CALENDAR DATA: Today is $today. '
            'The user\'s planner is empty — no scheduled events. '
            'Only mention this if the user asks about their schedule.';
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CHAT] calendar context error: $e');
      // Non-critical — degrade gracefully.
    }

    // Inject long-term memory context so the agent recalls past conversations,
    // user preferences, and behavioural patterns accumulated over time.
    // Memories are ranked by relevance to the current user message so BJ
    // recalls the most pertinent facts rather than just the highest-scored ones.
    String? memoryContext;
    try {
      final memories = await ref.read(userMemoriesProvider.future);
      if (memories.isNotEmpty) {
        final ranked = _rankMemoriesByRelevance(memories, text);
        final top = ranked.take(15).toList();
        final lines = top.map((m) => '- [${m.memoryType}] ${m.content}').join('\n');
        memoryContext =
            'You have the following long-term memories about this user, '
            'selected for relevance to their current message. Use them to '
            'personalise your responses, recall topics they have mentioned '
            'before, and proactively offer relevant suggestions:\n$lines';
        // ignore: avoid_print
        print('[CHAT] injecting ${top.length} memories (relevance-ranked) for query: "$text"');
      }
    } catch (_) {
      // Non-critical — agent degrades to stateless mode if fetch fails.
    }

    // Memobase: deep profile-based memory proxied through Railway backend.
    // The API key lives server-side; Flutter only sends its Firebase ID token.
    String? memobaseContext;
    try {
      final memobaseRepo = ref.read(memobaseRepositoryProvider);
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        final ctx = await memobaseRepo.getContext(
          userId: user.uid,
          query: text,
          maxTokens: 400,
        );
        if (ctx != null && ctx.isNotEmpty) {
          memobaseContext = ctx;
          // ignore: avoid_print
          print('[CHAT] memobase context injected (${ctx.length} chars)');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CHAT] memobase context error (non-critical): $e');
    }

    // Build the message list. Context hints are never stored in state and
    // never shown in the UI.
    //
    // Calendar and memory are injected as `system` messages AND also
    // appended directly to the user's current message. The dual-injection
    // approach ensures the data is visible to the model regardless of how
    // the backend processes system messages:
    //
    //   • system injection: caught by backends that honour extra system turns.
    //   • user-message append: impossible to strip; overrides any backend
    //     system prompt that claims the AI cannot access calendars, because
    //     the factual data is present in the conversation itself.
    //
    // Note: `lastUserMessage` and `hermesMessages` are backend-only copies
    // built from `baseMessages`; `state` (what the UI shows) is unchanged.
    //
    // Tone / music hints remain as system messages (stylistic, not factual).
    final priorMessages =
        baseMessages.isEmpty ? <Map<String, String>>[] : baseMessages.sublist(0, baseMessages.length - 1);
    final rawLastUserMessage =
        baseMessages.isEmpty ? null : baseMessages.last;

    // Augment the current user message with calendar + memory context so it
    // survives backend system-prompt overrides.  The UI always shows the
    // original text from `state`; only the backend payload is enriched.
    final Map<String, String>? lastUserMessage = () {
      if (rawLastUserMessage == null) return null;
      final parts = <String>[rawLastUserMessage['content'] ?? ''];
      if (calendarContext != null) parts.add('\n\n---\n$calendarContext');
      if (memoryContext != null) parts.add('\n\n---\n$memoryContext');
      if (memobaseContext != null) parts.add('\n\n---\n$memobaseContext');
      return {'role': 'user', 'content': parts.join()};
    }();

    final hermesMessages = [
      if (toneHint != null) {'role': 'system', 'content': toneHint},
      if (musicSuggestionHint != null)
        {'role': 'system', 'content': musicSuggestionHint},
      // Also keep as system messages for backends that process them first.
      if (calendarContext != null)
        {'role': 'system', 'content': calendarContext},
      if (memoryContext != null)
        {'role': 'system', 'content': memoryContext},
      if (memobaseContext != null)
        {'role': 'system', 'content': memobaseContext},
      ...priorMessages,
      if (lastUserMessage != null) lastUserMessage,
    ];

    final config = await ref.read(assistantConfigProvider.future);
    final assistantName = config?.name ?? 'Rocky';
    // ignore: avoid_print
    print('[CHAT] assistantName=$assistantName');

    final client = ref.read(hermesClientProvider);
    final aiModel = await ref
        .read(aiModelNotifierProvider.future)
        .catchError((_) => 'gemini_flash');
    // ignore: avoid_print
    print('[CHAT] aiModel=$aiModel baseUrl=${client.baseUrl}');

    final buffer = StringBuffer();
    var moodSaved = false;

    try {
      // ignore: avoid_print
      print('[CHAT] starting chatStream');
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
          case ErrorChunk(:final message):
            final errMessages = List<ChatMessage>.from(state);
            errMessages[assistantIndex] = ChatMessage(
              role: MessageRole.assistant,
              content: message,
              isStreaming: false,
            );
            state = errMessages;
            return;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CHAT] stream error: $e');
      final errMessages = List<ChatMessage>.from(state);
      errMessages[assistantIndex] = ChatMessage(
        role: MessageRole.assistant,
        content: "Sorry, I couldn't reach the server. Please try again.",
        isStreaming: false,
      );
      state = errMessages;
      return;
    }

    final finalContent = buffer.toString();

    // Guard: empty response means the AI provider failed silently on the backend.
    if (finalContent.isEmpty) {
      final errMessages = List<ChatMessage>.from(state);
      errMessages[assistantIndex] = ChatMessage(
        role: MessageRole.assistant,
        content: "Sorry, I couldn't get a response. Please try again.",
        isStreaming: false,
      );
      state = errMessages;
      return;
    }

    final parsed = parseScheduledEventFull(finalContent);
    final eventMap = parsed?.eventMap;
    // ignore: avoid_print
    print('[CHAT] eventMap=$eventMap hasFence=${finalContent.contains('```json')}');

    Event? createdEvent;
    // Only persist a calendar event when the user explicitly asked to schedule
    // something. The AI sometimes generates schedule_event JSON even during
    // normal conversation; the intent gate prevents those false saves.
    if (eventMap != null && _userRequestedScheduling(text)) {
      createdEvent = await _persistEvent(eventMap);
      // ignore: avoid_print
      print('[CHAT] createdEvent=$createdEvent');
      if (createdEvent != null) {
        ref.invalidate(plannerNotifierProvider);
      }
    }

    // Strip the JSON block (fenced or inline) so it never shows in the chat
    // bubble. Using the exact matched source string avoids false positives.
    var displayContent = finalContent;
    if (parsed != null) {
      displayContent = displayContent.replaceFirst(parsed.source, '');
    }
    // Also strip any remaining fenced code blocks just in case.
    displayContent = displayContent
        .replaceAll(RegExp(r'```json.*?```', dotAll: true), '')
        .trim();

    final finalMessages = List<ChatMessage>.from(state);
    finalMessages[assistantIndex] = ChatMessage(
      role: MessageRole.assistant,
      content: displayContent.isNotEmpty ? displayContent : finalContent,
      isStreaming: false,
      scheduledEvent: createdEvent != null ? eventMap : null,
    );
    state = finalMessages;

    // ── Memobase: persist this conversation turn ──────────────────────────────
    // Fire-and-forget — never block the UI on memory writes.
    unawaited(_insertMemobaseTurn(
      userMessage: text,
      assistantReply: displayContent.isNotEmpty ? displayContent : finalContent,
    ));

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

  /// Sends the completed conversation turn to Memobase so it can update the
  /// user's profile over time. Silently no-ops if the key is not configured.
  Future<void> _insertMemobaseTurn({
    required String userMessage,
    required String assistantReply,
  }) async {
    try {
      final memobaseRepo = ref.read(memobaseRepositoryProvider);
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;
      await memobaseRepo.insertChatBlob(
        userId: user.uid,
        messages: [
          {'role': 'user', 'content': userMessage},
          {'role': 'assistant', 'content': assistantReply},
        ],
      );
      // ignore: avoid_print
      print('[CHAT] memobase turn inserted for uid=${user.uid}');
    } catch (e) {
      // ignore: avoid_print
      print('[CHAT] memobase insert error (non-critical): $e');
    }
  }

  /// Returns true only when the user's message is clearly about their
  /// calendar or schedule. Kept intentionally narrow — when in doubt, don't
  /// inject. Broad words like "today", "tomorrow", "meeting" are excluded
  /// because they appear constantly in non-calendar conversation.
  bool _queryNeedsCalendar(String text) {
    final lower = text.toLowerCase();
    const triggers = [
      // Explicit calendar references
      'my calendar', 'my schedule', 'my planner', 'my agenda',
      'my appointments', 'my appointment', 'my events',
      // Clear query intent
      'what do i have', "what's on my", 'what is on my',
      'do i have any', 'any events', 'any appointments', 'any meetings',
      'show my', 'check my calendar', 'check my schedule',
      'upcoming events', 'upcoming appointments',
      // Explicit scheduling actions
      'add to calendar', 'add to my calendar',
      'add an event', 'add a meeting', 'add an appointment',
      'create event', 'create a meeting', 'schedule a meeting',
      'schedule an', 'new event', 'set a reminder', 'set reminder',
      'am i free', 'am i available', 'am i busy',
      'reschedule', 'cancel the',
    ];
    return triggers.any((t) => lower.contains(t));
  }

  /// Returns true only when the user's message contains explicit scheduling
  /// intent. This prevents the AI from silently creating calendar events during
  /// normal conversation when it spontaneously emits a schedule_event block.
  bool _userRequestedScheduling(String userMessage) {
    final lower = userMessage.toLowerCase();
    const triggers = [
      'schedule',
      'add event',
      'add to calendar',
      'create event',
      'set a reminder',
      'remind me',
      'book',
      'plan ',
      'put it in',
      'calendar',
      'add a meeting',
      'add meeting',
      'set up a',
      'set up an',
      'add an event',
      'add a reminder',
      'note it',
      'log it',
      'mark it',
      'put on my calendar',
    ];
    return triggers.any((t) => lower.contains(t));
  }

  Future<Event?> _persistEvent(Map<String, dynamic> eventMap) async {
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      // ignore: avoid_print
      print('[PERSIST] user=${user?.uid} eventMap=$eventMap');
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
      final saved = await repo.createEvent(event);
      // ignore: avoid_print
      print('[PERSIST] saved event id=${saved.id} title=${saved.title} start=${saved.startTime}');
      return saved;
    } on Exception catch (e, st) {
      // ignore: avoid_print
      print('[PERSIST] Exception: $e\n$st');
      return null;
    } catch (e, st) {
      // ignore: avoid_print
      print('[PERSIST] Error (non-Exception): $e\n$st');
      rethrow;
    }
  }

  /// Ranks memories by relevance to the current user message.
  ///
  /// Scoring combines three signals:
  ///   1. **Keyword overlap** (0–1): what fraction of message words appear in
  ///      the memory content — catches direct topic matches.
  ///   2. **Type affinity** (0–0.3): boosts memories whose type aligns with the
  ///      detected intent (e.g. asking about work boosts work_context memories).
  ///   3. **Reliability** (0–0.2): reinforcement × confidence, normalised —
  ///      ensures frequently confirmed facts score slightly higher when all else
  ///      is equal.
  ///
  /// Final score is capped at 1.0. Memories with zero keyword overlap still
  /// receive a small reliability score so foundational facts (name, job, etc.)
  /// are never completely excluded.
  List<Memory> _rankMemoriesByRelevance(List<Memory> memories, String query) {
    // Tokenise the user message into lowercase words (≥3 chars to skip noise).
    final queryTokens = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toSet();

    // Detect intent signals for type affinity boost.
    final lowerQuery = query.toLowerCase();
    final wantsWork = _containsAny(lowerQuery,
        ['work', 'job', 'project', 'meeting', 'colleague', 'boss', 'office', 'task']);
    final wantsPrefs = _containsAny(lowerQuery,
        ['like', 'love', 'prefer', 'favourite', 'enjoy', 'hate', 'dislike']);
    final wantsGoals = _containsAny(lowerQuery,
        ['goal', 'plan', 'want to', 'trying to', 'ambition', 'dream']);
    final wantsRoutine = _containsAny(lowerQuery,
        ['morning', 'evening', 'routine', 'habit', 'usually', 'always', 'every day']);
    final wantsPerson = _containsAny(lowerQuery,
        ['who', 'friend', 'family', 'partner', 'wife', 'husband', 'relationship']);
    final wantsFeel = _containsAny(lowerQuery,
        ['feel', 'feeling', 'mood', 'stress', 'happy', 'sad', 'anxious', 'excited']);

    // Max reliability for normalisation (avoid division by zero).
    final maxReliability = memories.fold<double>(
      1.0,
      (m, e) => (e.reinforcementCount * e.confidence) > m
          ? e.reinforcementCount * e.confidence
          : m,
    );

    double score(Memory m) {
      // 1. Keyword overlap — jaccard-style: overlapping tokens / query tokens.
      final memTokens = m.content
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3)
          .toSet();
      final overlap = queryTokens.isEmpty
          ? 0.0
          : memTokens.intersection(queryTokens).length / queryTokens.length;
      final keywordScore = overlap.clamp(0.0, 1.0);

      // 2. Type affinity boost.
      double typeBoost = 0.0;
      final t = m.memoryType;
      if (wantsWork && t == 'work_context') typeBoost = 0.30;
      if (wantsPrefs && t == 'preference') typeBoost = 0.30;
      if (wantsGoals && t == 'goal') typeBoost = 0.30;
      if (wantsRoutine && t == 'routine') typeBoost = 0.30;
      if (wantsPerson && t == 'relationship') typeBoost = 0.30;
      if (wantsFeel && t == 'emotional_signal') typeBoost = 0.30;
      // Personal facts always get a small base boost so core info stays present.
      if (t == 'personal_fact') typeBoost = (typeBoost + 0.10).clamp(0.0, 0.30);

      // 3. Reliability (normalised to 0–0.2).
      final reliabilityScore =
          ((m.reinforcementCount * m.confidence) / maxReliability) * 0.20;

      return (keywordScore + typeBoost + reliabilityScore).clamp(0.0, 1.0);
    }

    return [...memories]..sort((a, b) => score(b).compareTo(score(a)));
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);

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
