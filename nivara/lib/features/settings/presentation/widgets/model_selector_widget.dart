import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_model_provider.dart';
import '../../../subscription/domain/model_budget.dart';
import '../../../subscription/domain/subscription_tier.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';

/// Describes a model row shown in the selector.
class _ModelRow {
  const _ModelRow({
    required this.id,
    required this.label,
    required this.subtitle,
  });
  final String id;
  final String label;
  final String subtitle;
}

const _allModels = [
  _ModelRow(
    id: kModelGeminiFlash,
    label: 'Gemini 2.0 Flash',
    subtitle: 'Default — gives you the most messages',
  ),
  _ModelRow(
    id: kModelGpt4oMini,
    label: 'GPT-4o Mini',
    subtitle: 'Better for research',
  ),
  _ModelRow(
    id: kModelClaudeHaiku,
    label: 'Claude Haiku 3.5',
    subtitle: 'Best writing quality',
  ),
  _ModelRow(
    id: kModelClaudeSonnet,
    label: 'Claude Sonnet',
    subtitle: 'Deepest reasoning',
  ),
  _ModelRow(
    id: kModelGpt4o,
    label: 'GPT-4o',
    subtitle: 'Deepest reasoning',
  ),
];

/// Tier-aware model selector.
///
/// - Free: only Gemini Flash selectable; all others show a lock icon.
/// - Pro: Gemini Flash, GPT-4o Mini, Claude Haiku selectable.
/// - Premium: all five models selectable.
///
/// Each row displays the dynamic monthly message quota for the selected tier.
class ModelSelectorWidget extends ConsumerWidget {
  const ModelSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(aiModelNotifierProvider);
    final tierConfig = ref.watch(tierConfigProvider);
    final tier =
        ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;

    return modelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Text('Error: $e'),
      data: (selected) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Callout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Gemini Flash gives you the most messages. '
              'Switch to another model when you need deeper research '
              'or higher quality responses.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),

          ..._allModels.map((model) {
            final isAvailable =
                tierConfig.availableModels.contains(model.id);
            final quota = ModelBudget.messagesPerMonth(
              budgetUsd: tierConfig.monthlyBudgetUsd,
              model: model.id,
            );
            final quotaLabel = _formatQuota(quota, tier);

            return RadioListTile<String>(
              value: model.id,
              groupValue: selected,
              title: Row(
                children: [
                  Expanded(child: Text(model.label)),
                  if (!isAvailable)
                    const Icon(Icons.lock_outline,
                        size: 16, color: Colors.grey),
                ],
              ),
              subtitle: Text(
                isAvailable
                    ? '${model.subtitle} · $quotaLabel'
                    : '${model.subtitle} · Upgrade to unlock',
                style: TextStyle(
                  color: isAvailable
                      ? null
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              toggleable: false,
              onChanged: isAvailable
                  ? (v) {
                      if (v != null) {
                        unawaited(
                            ref.read(aiModelNotifierProvider.notifier).setModel(v));
                      }
                    }
                  : null,
            );
          }),
        ],
      ),
    );
  }

  String _formatQuota(int quota, SubscriptionTier tier) {
    if (quota >= 100000) {
      return '~${(quota / 1000).round()}k msgs/month';
    } else if (quota >= 1000) {
      return '~${(quota / 1000.0).toStringAsFixed(1).replaceAll('.0', '')}k msgs/month';
    }
    return '~$quota msgs/month';
  }
}
