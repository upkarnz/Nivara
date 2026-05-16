import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/revenue_cat_service.dart';
import '../providers/subscription_providers.dart';

/// Full-screen bottom sheet that presents Pro and Premium upgrade options.
///
/// Shown when the user's quota is fully exhausted (inGrace=false, exhausted=true).
class PaywallSheet extends ConsumerWidget {
  const PaywallSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Upgrade Nivara',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You've used all your messages this month.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Pro tier card
            _TierCard(
              name: 'Pro',
              price: '\$7.99/month',
              features: const [
                'Unlimited messages (Gemini Flash)',
                'Unlimited chat history',
                'Background music',
                '30 wake word activations/month',
                'Switch to GPT-4o Mini or Claude Haiku',
              ],
              ctaLabel: 'Upgrade to Pro',
              onTap: () => _handleUpgrade(context, ref, tier: 'pro'),
            ),
            const SizedBox(height: 16),

            // Premium tier card
            _TierCard(
              name: 'Premium',
              price: '\$19.99/month',
              features: const [
                'Unlimited messages (all models)',
                'ElevenLabs TTS voices',
                'Unlimited wake word activations',
                'Access to Claude Sonnet & GPT-4o',
              ],
              ctaLabel: 'Upgrade to Premium',
              onTap: () => _handleUpgrade(context, ref, tier: 'premium'),
              highlighted: true,
            ),
            const SizedBox(height: 24),

            // Restore Purchases
            Center(
              child: TextButton(
                onPressed: () => _handleRestore(context, ref),
                child: const Text('Restore Purchases'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpgrade(
    BuildContext context,
    WidgetRef ref, {
    required String tier,
  }) async {
    // RevenueCatServiceImpl.purchasePackage() will be wired in Task 14.
    // For now show a snackbar placeholder.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchasing $tier…')),
      );
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
      ref.invalidate(subscriptionProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed. Please try again.')),
        );
      }
    }
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.name,
    required this.price,
    required this.features,
    required this.ctaLabel,
    required this.onTap,
    this.highlighted = false,
  });

  final String name;
  final String price;
  final List<String> features;
  final String ctaLabel;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: highlighted ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: highlighted ? colorScheme.primary : null,
                      ),
                ),
                Text(
                  price,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16,
                        color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(f,
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                child: Text(ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
