import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatNotifierProvider);
    final configAsync = ref.watch(assistantConfigProvider);
    final isStreaming = messages.isNotEmpty && messages.last.isStreaming;

    return Scaffold(
      appBar: AppBar(
        title: configAsync.when(
          data: (c) => Text(c?.name ?? 'Nivara'),
          loading: () => const Text('Nivara'),
          error: (_, __) => const Text('Nivara'),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
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
            onSend: (text) =>
                ref.read(chatNotifierProvider.notifier).sendMessage(text),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
