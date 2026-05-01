import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

class AssistantSetupPage extends ConsumerStatefulWidget {
  const AssistantSetupPage({super.key});

  @override
  ConsumerState<AssistantSetupPage> createState() => _AssistantSetupPageState();
}

class _AssistantSetupPageState extends ConsumerState<AssistantSetupPage> {
  final _nameCtrl = TextEditingController(text: 'Rocky');
  String _voice = 'neutral';
  String _style = 'friendly';
  bool _saving = false;

  Future<void> _save() async {
    final assistantName = _nameCtrl.text.trim();
    if (assistantName.isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    final config = AssistantConfig(
      name: assistantName,
      voice: _voice,
      speed: 'normal',
      style: _style,
      wakePhrase: 'Hey $assistantName',
      aiModel: 'claude',
    );
    await ref.read(profileRepositoryProvider).saveAssistant(user.uid, config);
    if (mounted) context.go('/chat');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Name Your Assistant'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Give your AI companion a name.\nYou can change this any time.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Assistant Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _voice,
                decoration: const InputDecoration(labelText: 'Voice'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
                ],
                onChanged: (v) => setState(() => _voice = v ?? 'neutral'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _style,
                decoration:
                    const InputDecoration(labelText: 'Conversation Style'),
                items: const [
                  DropdownMenuItem(value: 'friendly', child: Text('Friendly')),
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(value: 'formal', child: Text('Formal')),
                ],
                onChanged: (v) => setState(() => _style = v ?? 'friendly'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Meet Your Assistant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
