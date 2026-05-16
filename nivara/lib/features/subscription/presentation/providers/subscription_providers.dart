import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quota_repository.dart';
import '../../data/revenue_cat_service.dart';
import '../../domain/model_budget.dart';
import '../../domain/subscription_tier.dart';
import '../../../settings/presentation/providers/ai_model_provider.dart';

// ---------------------------------------------------------------------------
// QuotaState
// ---------------------------------------------------------------------------

/// Computed quota state for the current billing period.
class QuotaState {
  const QuotaState({
    required this.messagesUsed,
    required this.monthlyQuota,
    required this.remaining,
    required this.graceUsed,
    required this.inGrace,
    required this.exhausted,
    required this.graceRemaining,
  });

  final int messagesUsed;
  final int monthlyQuota;

  /// May be negative when user has sent messages beyond the quota.
  final int remaining;
  final int graceUsed;

  /// User has exhausted the quota but still has grace messages left.
  final bool inGrace;

  /// User has exhausted both the quota and all 3 grace messages.
  final bool exhausted;

  /// How many grace messages the user still has (0–3).
  final int graceRemaining;

  factory QuotaState.fromDoc({
    required QuotaDoc doc,
    required int monthlyQuota,
  }) {
    final remaining = monthlyQuota - doc.messagesUsed;
    final inGrace = remaining <= 0 && doc.graceUsed < 3;
    final exhausted = remaining <= 0 && doc.graceUsed >= 3;
    return QuotaState(
      messagesUsed: doc.messagesUsed,
      monthlyQuota: monthlyQuota,
      remaining: remaining,
      graceUsed: doc.graceUsed,
      inGrace: inGrace,
      exhausted: exhausted,
      graceRemaining: 3 - doc.graceUsed,
    );
  }

  @override
  String toString() =>
      'QuotaState(used=$messagesUsed/$monthlyQuota, grace=$graceUsed/3, '
      'inGrace=$inGrace, exhausted=$exhausted)';
}

// ---------------------------------------------------------------------------
// subscriptionProvider
// ---------------------------------------------------------------------------

/// Resolves the user's current [SubscriptionTier] via RevenueCat.
/// Defaults to [SubscriptionTier.free] on error.
final subscriptionProvider = FutureProvider<SubscriptionTier>((ref) async {
  return ref.read(revenueCatServiceProvider).getCurrentTier();
});

// ---------------------------------------------------------------------------
// tierConfigProvider
// ---------------------------------------------------------------------------

/// Synchronously exposes the [TierConfig] for the current subscription tier.
final tierConfigProvider = Provider<TierConfig>((ref) {
  final tier =
      ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;
  return TierConfig.forTier(tier);
});

// ---------------------------------------------------------------------------
// quotaProvider
// ---------------------------------------------------------------------------

/// Stream of the user's computed [QuotaState], derived from:
///  - their subscription tier (budget)
///  - their selected AI model (cost-per-message)
///  - live Firestore quota document
final quotaProvider = StreamProvider<QuotaState>((ref) async* {
  final tier =
      ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;
  final model =
      ref.watch(aiModelNotifierProvider).valueOrNull ?? kDefaultModel;
  final tierConfig = TierConfig.forTier(tier);
  final monthlyQuota = ModelBudget.messagesPerMonth(
    budgetUsd: tierConfig.monthlyBudgetUsd,
    model: model,
  );

  // Guard: only proceed when a user is authenticated.
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final repo = ref.read(quotaRepositoryProvider);
  await repo.resetIfNewPeriod();

  await for (final doc in repo.getQuota()) {
    yield QuotaState.fromDoc(doc: doc, monthlyQuota: monthlyQuota);
  }
});
