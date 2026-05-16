import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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

/// Production implementation backed by the RevenueCat SDK.
///
/// Entitlement IDs must match those configured in the RevenueCat dashboard:
/// - `"pro"`     → [SubscriptionTier.pro]
/// - `"premium"` → [SubscriptionTier.premium]
class RevenueCatServiceImpl implements RevenueCatService {
  @override
  Future<void> init(String apiKey) async {
    await Purchases.setLogLevel(LogLevel.warn);
    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
  }

  @override
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlements = info.entitlements.active;
      if (entitlements.containsKey('premium')) return SubscriptionTier.premium;
      if (entitlements.containsKey('pro')) return SubscriptionTier.pro;
      return SubscriptionTier.free;
    } on PlatformException {
      // Network or SDK errors — degrade gracefully to Free.
      return SubscriptionTier.free;
    }
  }

  @override
  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}

/// Riverpod provider for [RevenueCatService].
///
/// Override this with [RevenueCatServiceImpl] in [main.dart] via
/// `ProviderScope(overrides: [revenueCatServiceProvider.overrideWithValue(...)])`.
final revenueCatServiceProvider = Provider<RevenueCatService>(
  (_) => RevenueCatServiceStub(),
);
