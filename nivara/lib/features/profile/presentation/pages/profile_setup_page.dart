import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
  DateTime? _dob;
  String _voicePreference = 'neutral';
  bool _saving = false;

  static const _languages = [
    ('en', 'English'),
    ('hi', 'Hindi'),
    ('es', 'Spanish'),
    ('fr', 'French'),
    ('de', 'German'),
    ('zh', 'Chinese'),
    ('ja', 'Japanese'),
    ('ar', 'Arabic'),
  ];

  static const _voiceOptions = [
    (
      value: 'female',
      label: 'Female',
      icon: Icons.record_voice_over_outlined,
      description: 'Warm & expressive',
    ),
    (
      value: 'neutral',
      label: 'Neutral',
      icon: Icons.spatial_audio_outlined,
      description: 'Balanced & clear',
    ),
    (
      value: 'male',
      label: 'Male',
      icon: Icons.mic_outlined,
      description: 'Deep & confident',
    ),
  ];

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5),
      helpText: 'Select your date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    final profile = UserProfile.empty().copyWith(
      name: _nameCtrl.text.trim(),
      gender: _gender,
      language: _language,
      dob: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '',
      voicePreference: _voicePreference,
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
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: Colors.transparent,
              floating: true,
              title: Text('About You'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  Text(
                    'Let\'s personalise your experience',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white60),
                  ),
                  const SizedBox(height: 32),

                  // ── Name ──────────────────────────────────────────────────
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Your Name *',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Date of Birth ─────────────────────────────────────────
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDob,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _dob != null
                            ? DateFormat('d MMM yyyy').format(_dob!)
                            : 'Tap to select',
                        style: _dob != null
                            ? null
                            : const TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Gender ────────────────────────────────────────────────
                  DropdownButtonFormField<String>(
                    value: _gender.isEmpty ? null : _gender,
                    decoration: InputDecoration(
                      labelText: 'Gender (optional)',
                      prefixIcon: const Icon(Icons.wc_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    hint: const Text('Select gender'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(
                          value: 'non-binary', child: Text('Non-binary')),
                      DropdownMenuItem(
                          value: 'prefer-not',
                          child: Text('Prefer not to say')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? ''),
                  ),
                  const SizedBox(height: 20),

                  // ── Language ──────────────────────────────────────────────
                  DropdownButtonFormField<String>(
                    value: _language,
                    decoration: InputDecoration(
                      labelText: 'Preferred Language',
                      prefixIcon: const Icon(Icons.language_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _languages
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.$1,
                            child: Text(l.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _language = v ?? 'en'),
                  ),
                  const SizedBox(height: 28),

                  // ── Voice Preference ──────────────────────────────────────
                  _VoicePickerSection(
                    selected: _voicePreference,
                    options: _voiceOptions,
                    onChanged: (v) => setState(() => _voicePreference = v),
                  ),
                  const SizedBox(height: 40),

                  // ── Continue button ───────────────────────────────────────
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice picker

typedef _VoiceOption = ({
  String value,
  String label,
  IconData icon,
  String description,
});

class _VoicePickerSection extends StatelessWidget {
  const _VoicePickerSection({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String selected;
  final List<_VoiceOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.record_voice_over, size: 18, color: Colors.white54),
            const SizedBox(width: 8),
            Text(
              'Assistant Voice',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: options
              .map(
                (opt) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: opt.value == options.last.value ? 0 : 10,
                    ),
                    child: _VoiceCard(
                      option: opt,
                      isSelected: selected == opt.value,
                      onTap: () => onChanged(opt.value),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _VoiceOption option;
  final bool isSelected;
  final VoidCallback onTap;

  static const _accent = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? _accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected ? _accent : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 28,
              color: isSelected ? _accent : Colors.white54,
            ),
            const SizedBox(height: 8),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.description,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? _accent.withValues(alpha: 0.9)
                    : Colors.white38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
