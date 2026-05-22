import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../subscription/domain/subscription_tier.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../subscription/presentation/widgets/paywall_sheet.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../music/data/spotify_settings_provider.dart';
import '../widgets/model_selector_widget.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // User profile controllers
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  String _gender = '';
  String _language = 'en';
  DateTime? _dob;
  String _voicePreference = 'neutral';
  bool _profileSaving = false;
  bool _profileLoaded = false;

  // Assistant controllers
  final _assistantNameCtrl = TextEditingController();
  String _assistantVoice = 'neutral';
  String _assistantStyle = 'friendly';
  bool _assistantSaving = false;
  bool _assistantLoaded = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final repo = ref.read(profileRepositoryProvider);

    final profile = await repo.getProfile(user.uid);
    if (mounted && profile != null && !_profileLoaded) {
      setState(() {
        _nameCtrl.text = profile.name;
        _nicknameCtrl.text = profile.nickname;
        _gender = profile.gender;
        _language = profile.language.isNotEmpty ? profile.language : 'en';
        _voicePreference = profile.voicePreference.isNotEmpty
            ? profile.voicePreference
            : 'neutral';
        if (profile.dob.isNotEmpty) {
          try {
            _dob = DateFormat('yyyy-MM-dd').parse(profile.dob);
          } catch (_) {}
        }
        _profileLoaded = true;
      });
    }

    final assistant = await repo.getAssistant(user.uid);
    if (mounted && assistant != null && !_assistantLoaded) {
      setState(() {
        _assistantNameCtrl.text = assistant.name;
        _assistantVoice = assistant.voice.isNotEmpty ? assistant.voice : 'neutral';
        _assistantStyle = assistant.style.isNotEmpty ? assistant.style : 'friendly';
        _assistantLoaded = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _profileSaving = true);
    final profile = UserProfile.empty().copyWith(
      name: _nameCtrl.text.trim(),
      nickname: _nicknameCtrl.text.trim(),
      gender: _gender,
      language: _language,
      dob: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '',
      voicePreference: _voicePreference,
    );
    await ref.read(profileRepositoryProvider).saveProfile(user.uid, profile);
    if (mounted) {
      setState(() => _profileSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    }
  }

  Future<void> _saveAssistant() async {
    if (_assistantNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant name is required')),
      );
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _assistantSaving = true);
    final assistantName = _assistantNameCtrl.text.trim();
    final config = AssistantConfig(
      name: assistantName,
      voice: _assistantVoice,
      speed: 'normal',
      style: _assistantStyle,
      wakePhrase: 'Hey $assistantName',
      aiModel: 'claude',
    );
    await ref.read(profileRepositoryProvider).saveAssistant(user.uid, config);
    if (mounted) {
      setState(() => _assistantSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant settings saved')),
      );
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _assistantNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final tier =
        ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── Profile card ──────────────────────────────────────────────────
          profileAsync.when(
            data: (profile) => _ProfileCard(
              name: profile?.name ?? 'User',
              tier: tier,
            ),
            loading: () => const _ProfileCardSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── USER PROFILE section ──────────────────────────────────────────
          const _SectionHeader('User Profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Nickname
                TextField(
                  controller: _nicknameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nickname (optional)',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Date of Birth
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _dob != null
                          ? DateFormat('d MMM yyyy').format(_dob!)
                          : 'Tap to select',
                      style: _dob != null
                          ? null
                          : TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Gender
                DropdownButtonFormField<String>(
                  value: _gender.isEmpty ? null : _gender,
                  decoration: InputDecoration(
                    labelText: 'Gender (optional)',
                    prefixIcon: const Icon(Icons.wc_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(height: 12),

                // Language
                DropdownButtonFormField<String>(
                  value: _language,
                  decoration: InputDecoration(
                    labelText: 'Preferred Language',
                    prefixIcon: const Icon(Icons.language_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _languages
                      .map((l) => DropdownMenuItem(
                            value: l.$1,
                            child: Text(l.$2),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _language = v ?? 'en'),
                ),
                const SizedBox(height: 16),

                // Voice preference
                _VoiceRow(
                  label: 'Preferred Voice',
                  selected: _voicePreference,
                  onChanged: (v) => setState(() => _voicePreference = v),
                ),
                const SizedBox(height: 20),

                // Save Profile button
                ElevatedButton(
                  onPressed: _profileSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _profileSaving
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary),
                        )
                      : const Text('Save Profile',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // ── AI ASSISTANT section ──────────────────────────────────────────
          const _SectionHeader('AI Assistant'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Assistant name
                TextField(
                  controller: _assistantNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Assistant Name',
                    prefixIcon: const Icon(Icons.face_retouching_natural_outlined),
                    helperText: 'What do you want to call your AI?',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Voice
                DropdownButtonFormField<String>(
                  value: _assistantVoice,
                  decoration: InputDecoration(
                    labelText: 'Voice',
                    prefixIcon: const Icon(Icons.record_voice_over_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male — Deep & confident')),
                    DropdownMenuItem(value: 'female', child: Text('Female — Warm & expressive')),
                    DropdownMenuItem(value: 'neutral', child: Text('Neutral — Balanced & clear')),
                  ],
                  onChanged: (v) =>
                      setState(() => _assistantVoice = v ?? 'neutral'),
                ),
                const SizedBox(height: 12),

                // Conversation style
                DropdownButtonFormField<String>(
                  value: _assistantStyle,
                  decoration: InputDecoration(
                    labelText: 'Conversation Style',
                    prefixIcon: const Icon(Icons.chat_bubble_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'friendly', child: Text('Friendly — Warm & encouraging')),
                    DropdownMenuItem(value: 'casual', child: Text('Casual — Relaxed & informal')),
                    DropdownMenuItem(value: 'formal', child: Text('Formal — Professional & precise')),
                    DropdownMenuItem(value: 'motivational', child: Text('Motivational — Energetic & uplifting')),
                  ],
                  onChanged: (v) =>
                      setState(() => _assistantStyle = v ?? 'friendly'),
                ),
                const SizedBox(height: 20),

                // Save Assistant button
                ElevatedButton(
                  onPressed: _assistantSaving ? null : _saveAssistant,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _assistantSaving
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary),
                        )
                      : const Text('Save Assistant Settings',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // ── Music ────────────────────────────────────────────────────────
          const _SectionHeader('Music'),
          const _SpotifyConnectTile(),

          // ── Appearance ───────────────────────────────────────────────────
          const _SectionHeader('Appearance'),
          const _ThemeSelector(),

          // ── Voice & Wake Word ─────────────────────────────────────────────
          const _SectionHeader('Voice'),
          ListTile(
            leading: const Icon(Icons.mic_outlined),
            title: const Text('Voice & Wake Word'),
            subtitle: const Text('TTS engine, wake word settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/voice'),
          ),

          // ── AI Model ─────────────────────────────────────────────────────
          const _SectionHeader('AI Model'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ModelSelectorWidget(),
          ),

          // ── Subscription ─────────────────────────────────────────────────
          const _SectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(
              tier == SubscriptionTier.free
                  ? 'Free Plan'
                  : tier == SubscriptionTier.pro
                      ? 'Pro Plan'
                      : 'Premium Plan',
            ),
            subtitle: tier == SubscriptionTier.free
                ? const Text('Upgrade for more features')
                : const Text('Active subscription'),
            trailing: tier == SubscriptionTier.free
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: tier == SubscriptionTier.free
                ? () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const PaywallSheet(),
                    )
                : null,
          ),

          // ── Planner ───────────────────────────────────────────────────────
          const _SectionHeader('Planner'),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Google Calendar'),
            subtitle: const Text('Sync your calendar events'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/planner/calendar-consent'),
          ),

          // ── Account ───────────────────────────────────────────────────────
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('You will need to sign in again.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authRepositoryProvider).signOut();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: Color(0xFFEF4444)),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
            subtitle: const Text(
              'Permanently remove your account and all data',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Delete Account?', style: TextStyle(color: cs.onSurface)),
          content: Text(
            'This will permanently delete your account and all associated data '
            '(profile, chat history, memories, events). '
            'This action cannot be undone.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // Capture navigator / messenger before the async gap.
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading indicator while deleting.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      nav.pop(); // dismiss loader — auth stream redirects to sign-in automatically
    } on Exception catch (e) {
      nav.pop(); // dismiss loader
      final msg = e.toString().contains('requires-recent-login')
          ? 'Please sign out and sign back in, then try again.'
          : 'Failed to delete account. Please try again.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Voice row (3 chip options)

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('female', 'Female', Icons.record_voice_over_outlined),
    ('neutral', 'Neutral', Icons.spatial_audio_outlined),
    ('male', 'Male', Icons.mic_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          children: _options.map((opt) {
            final isSelected = selected == opt.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: opt.$1 == _options.last.$1 ? 0 : 8),
                child: GestureDetector(
                  onTap: () => onChanged(opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.12)
                          : cs.surface,
                      border: Border.all(
                        color: isSelected ? cs.primary : cs.outlineVariant,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.$3,
                            size: 22,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant),
                        const SizedBox(height: 6),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.tier});

  final String name;
  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    final tierLabel = switch (tier) {
      SubscriptionTier.free => 'Free',
      SubscriptionTier.pro => 'Pro',
      SubscriptionTier.premium => 'Premium',
    };
    final tierColor = switch (tier) {
      SubscriptionTier.free => Colors.grey,
      SubscriptionTier.pro => const Color(0xFF6366F1),
      SubscriptionTier.premium => Colors.amber,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF6366F1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tierLabel,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCardSkeleton extends StatelessWidget {
  const _ProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spotify connect tile (Pro / Premium only)

class _SpotifyConnectTile extends ConsumerStatefulWidget {
  const _SpotifyConnectTile();

  @override
  ConsumerState<_SpotifyConnectTile> createState() =>
      _SpotifyConnectTileState();
}

class _SpotifyConnectTileState extends ConsumerState<_SpotifyConnectTile> {
  final _idCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _obscureSecret = true;
  bool _expanded = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tierConfig = ref.watch(tierConfigProvider);
    final musicEnabled = tierConfig.musicEnabled; // true for Pro & Premium
    final spotifyAsync = ref.watch(spotifySettingsProvider);
    final spotify = spotifyAsync.valueOrNull ?? const SpotifySettings();

    // Pre-fill fields when settings load
    if (_idCtrl.text.isEmpty && spotify.clientId.isNotEmpty) {
      _idCtrl.text = spotify.clientId;
    }

    if (!musicEnabled) {
      // Show locked tile for Free users
      return ListTile(
        leading: const _SpotifyLogo(),
        title: const Text('Spotify'),
        subtitle: const Text(
          'Available on Pro and Premium plans.',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.lock_outline, color: Colors.amber),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const PaywallSheet(),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: const _SpotifyLogo(),
          title: const Text('Spotify'),
          subtitle: Text(
            spotify.connected
                ? 'Connected — mood-based playback active'
                : 'Connect to play Spotify tracks by mood',
            style: TextStyle(
              fontSize: 12,
              color: spotify.connected ? Colors.greenAccent : null,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spotify.connected)
                const Icon(Icons.check_circle_outline,
                    color: Colors.greenAccent, size: 20),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your Spotify app credentials. Create a free app at '
                  'developer.spotify.com to get your Client ID and Secret.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _idCtrl,
                  decoration: InputDecoration(
                    labelText: 'Client ID',
                    hintText: 'Paste your Spotify Client ID',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _secretCtrl,
                  obscureText: _obscureSecret,
                  decoration: InputDecoration(
                    labelText: 'Client Secret',
                    hintText: 'Paste your Spotify Client Secret',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureSecret
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscureSecret = !_obscureSecret),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('Connect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _idCtrl.text.trim().isEmpty ||
                                _secretCtrl.text.trim().isEmpty
                            ? null
                            : () async {
                                await ref
                                    .read(spotifySettingsProvider.notifier)
                                    .saveCredentials(
                                      clientId: _idCtrl.text,
                                      clientSecret: _secretCtrl.text,
                                    );
                                await ref
                                    .read(spotifySettingsProvider.notifier)
                                    .setConnected(true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Spotify connected ✓'),
                                      backgroundColor: Color(0xFF1DB954),
                                    ),
                                  );
                                  setState(() => _expanded = false);
                                }
                              },
                      ),
                    ),
                    if (spotify.connected) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await ref
                              .read(spotifySettingsProvider.notifier)
                              .disconnect();
                          _idCtrl.clear();
                          _secretCtrl.clear();
                          setState(() => _expanded = false);
                        },
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SpotifyLogo extends StatelessWidget {
  const _SpotifyLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.music_note, color: Colors.white, size: 20),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme selector — three chips: Dark / Light / System

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  static const _options = [
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: _options.map((opt) {
          final isSelected = current == opt.$1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: opt.$1 == _options.last.$1 ? 0 : 8),
              child: GestureDetector(
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.18)
                        : scheme.surfaceContainerHigh,
                    border: Border.all(
                      color:
                          isSelected ? scheme.primary : scheme.outlineVariant,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt.$3,
                        size: 22,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
