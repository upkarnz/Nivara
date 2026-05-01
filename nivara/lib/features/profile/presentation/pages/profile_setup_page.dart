import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nameCtrl = TextEditingController();
  String _gender = '';
  String _language = 'en';
  bool _saving = false;

  static const _languages = ['en', 'hi', 'es', 'fr', 'de', 'zh', 'ja', 'ar'];

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    final profile = UserProfile.empty().copyWith(
      name: _nameCtrl.text.trim(),
      gender: _gender,
      language: _language,
    );
    await ref.read(profileRepositoryProvider).saveProfile(user.uid, profile);
    if (mounted) context.go('/assistant-setup');
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
        title: const Text('About You'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Your Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender.isEmpty ? null : _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender (optional)',
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(
                    value: 'non-binary',
                    child: Text('Non-binary'),
                  ),
                  DropdownMenuItem(
                    value: 'prefer-not',
                    child: Text('Prefer not to say'),
                  ),
                ],
                onChanged: (v) => setState(() => _gender = v ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(labelText: 'Language'),
                items: _languages
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(l.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _language = v ?? 'en'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
