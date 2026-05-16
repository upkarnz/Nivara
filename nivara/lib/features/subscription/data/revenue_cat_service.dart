import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/subscription_tier.dart';

/// Abstract interface for RevenueCat subscription management.
///
/// Production code uses [RevenueCatServiceImpl] (added in Task 14).
/// Tests and non-production builds use [RevenueCatServiceStub].
abstract class RevenueCatService {
  /// Initialises the RevenueCat SDK with the given platform [apiKey].
  Future<void> init(String apiKey);

  /// Returns the user's current subscription tier based on active entitlements.
  Future<SubscriptionTier> getCurrentTier();

  /// Restores any previous purchases and updates the active entitlement.
  Future<void> restorePurchases();
}

/// No-op stub that always reports the Free tier.
/// Used in dev, test, and as the default before production override.
class RevenueCatServiceStub implements RevenueCatService {
  @override
  Future<void> init(String apiKey) async {}

  @override
  Future<SubscriptionTier> getCurrentTier() async => SubscriptionTier.free;

  @override
  Future<void> restorePurchases() async {}
}

/// Riverpod provider for [RevenueCatService].
///
/// Override this with [RevenueCatServiceImpl] in [main.dart] via
/// `ProviderScope(overrides: [revenueCatServiceProvider.overrideWithValue(...)])`.
final revenueCatServiceProvider = Provider<RevenueCatService>(
  (_) => RevenueCatServiceStub(),
);
