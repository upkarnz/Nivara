import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../subscription/domain/subscription_tier.dart';
import '../../../subscription/presentation/widgets/paywall_sheet.dart';
import '../widgets/model_selector_widget.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final configAsync = ref.watch(assistantConfigProvider);
    final tier = ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profile card
          profileAsync.when(
            data: (profile) => _ProfileCard(
              name: profile?.name ?? 'User',
              email: '',
              tier: tier,
              onTap: () => context.push('/profile-setup'),
            ),
            loading: () => const _ProfileCardSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const _SectionHeader('Assistant'),
          configAsync.when(
            data: (config) => ListTile(
              leading: const Icon(Icons.face_retouching_natural_outlined),
              title: Text(config?.name ?? 'Rocky'),
              subtitle: const Text('Tap to change assistant name & voice'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/assistant-setup'),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.face_retouching_natural_outlined),
              title: Text('Loading…'),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ListTile(
            leading: const Icon(Icons.mic_outlined),
            title: const Text('Voice & Wake Word'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/voice'),
          ),

          const _SectionHeader('AI Model'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ModelSelectorWidget(),
          ),

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

          const _SectionHeader('Planner'),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Google Calendar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/planner/calendar-consent'),
          ),

          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile-setup'),
          ),
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
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authRepositoryProvider).signOut();
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
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
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.tier,
    required this.onTap,
  });

  final String name;
  final String email;
  final SubscriptionTier tier;
  final VoidCallback onTap;

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

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ProfileCardSkeleton extends StatelessWidget {
  const _ProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
