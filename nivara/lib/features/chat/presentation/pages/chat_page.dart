import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../subscription/domain/subscription_tier.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../subscription/presentation/widgets/paywall_sheet.dart';
import '../../../subscription/presentation/widgets/quota_banner.dart';
import '../../../subscription/presentation/widgets/quota_indicator.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../../../../../voice/voice_fab.dart';
import '../../../mood/presentation/widgets/check_in_card.dart';
import '../../../mood/presentation/providers/mood_provider.dart';
import '../../../../services/mood_notification_service.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _showCheckIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_checkMorningCheckIn()),
    );
  }

  Future<void> _checkMorningCheckIn() async {
    try {
      final now = DateTime.now();
      if (now.hour >= 12) return;
      if (!mounted) return;
      final today = await ref.read(todayMoodProvider.future);
      if (today == null && mounted) {
        setState(() => _showCheckIn = true);
      }
    } catch (_) {
      // Non-critical: check-in prompt is best-effort; silently skip on error
    }
  }

  String _greeting(AssistantConfig? config) {
    final name = config?.name ?? 'Rocky';
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$timeOfDay! I\'m $name. How are you feeling today?';
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatNotifierProvider);
    final configAsync = ref.watch(assistantConfigProvider);
    final isStreaming = messages.isNotEmpty && messages.last.isStreaming;
    final quotaState = ref.watch(quotaProvider).valueOrNull;
    final tier =
        ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;

    return Scaffold(
      floatingActionButton: const VoiceFab(),
      appBar: AppBar(
        title: configAsync.when(
          data: (c) => Text(c?.name ?? 'Nivara'),
          loading: () => const Text('Nivara'),
          error: (_, __) => const Text('Nivara'),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Planner',
            onPressed: () => context.push('/planner'),
          ),
          IconButton(
            icon: const Icon(Icons.mood_outlined),
            tooltip: 'Mood',
            onPressed: () => context.push('/mood'),
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'My Memories',
            onPressed: () => context.push('/memory'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Voice settings',
            onPressed: () => context.push('/settings/voice'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await MoodNotificationService.cancelReminder();
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Grace message amber banner — visible only when inGrace=true
          if (quotaState != null) QuotaBanner(quotaState: quotaState),
          if (_showCheckIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CheckInCard(
                onDismiss: () => setState(() => _showCheckIn = false),
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: configAsync.when(
                      data: (c) => Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _greeting(c),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => MessageBubble(message: messages[i]),
                  ),
          ),
          ChatInputBar(
            enabled: !isStreaming,
            onSend: (text) {
              if (quotaState?.exhausted == true) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const PaywallSheet(),
                );
                return;
              }
              ref.read(chatNotifierProvider.notifier).sendMessage(text);
            },
          ),
          // Message counter — visible on Free tier only
          if (quotaState != null)
            QuotaIndicator(
              quotaState: quotaState,
              isFree: tier == SubscriptionTier.free,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
