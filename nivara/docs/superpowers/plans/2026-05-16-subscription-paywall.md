# Subscription + Paywall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add RevenueCat-powered Free/Pro/Premium subscription tiers with dynamic message quotas, model-selector gating, and a soft paywall (3 grace messages → hard block + bottom sheet).

**Architecture:** Domain layer defines `SubscriptionTier`, `TierConfig`, and `ModelBudget` as pure Dart. Firestore stores quota at `users/{uid}/quota`; RevenueCat manages entitlements. All quota checks are client-side via three plain Riverpod providers: `subscriptionProvider` (FutureProvider), `tierConfigProvider` (Provider), and `quotaProvider` (StreamProvider). The `ChatPage` shows UI (paywall sheet, grace banner, quota indicator); `ChatNotifier.sendMessage()` calls `QuotaRepository` after each message.

**Tech Stack:** `purchases_flutter` (RevenueCat), `cloud_firestore`, `flutter_riverpod`, Flutter material widgets.

---

## File Map

**New files:**
```
lib/features/subscription/domain/subscription_tier.dart        # SubscriptionTier enum + TierConfig
lib/features/subscription/domain/model_budget.dart             # ModelBudget pure utility
lib/features/subscription/data/revenue_cat_service.dart        # abstract RevenueCatService + stub
lib/features/subscription/data/quota_repository.dart           # QuotaDoc + QuotaRepository + provider
lib/features/subscription/data/wake_word_quota_repository.dart # WakeWordQuotaRepository + provider
lib/features/subscription/presentation/providers/subscription_provider.dart  # QuotaState + 3 providers
lib/features/subscription/presentation/widgets/paywall_sheet.dart
lib/features/subscription/presentation/widgets/quota_banner.dart
lib/features/subscription/presentation/widgets/quota_indicator.dart

test/features/subscription/domain/tier_config_test.dart
test/features/subscription/domain/model_budget_test.dart
test/features/subscription/presentation/quota_state_test.dart
test/features/subscription/presentation/quota_provider_test.dart
test/features/subscription/presentation/paywall_sheet_test.dart
test/features/subscription/presentation/quota_banner_test.dart
test/features/chat/chat_provider_quota_test.dart
```

**Modified files:**
```
pubspec.yaml                                                                  # + purchases_flutter
lib/main.dart                                                                 # + RevenueCat init
lib/features/settings/presentation/providers/ai_model_provider.dart          # new model IDs + default
lib/features/settings/presentation/widgets/model_selector_widget.dart        # tier-aware rows
lib/features/chat/presentation/providers/chat_provider.dart                  # quota tracking
lib/features/chat/presentation/pages/chat_page.dart                          # banner + indicator
lib/features/music/presentation/pages/music_page.dart                        # music gating
lib/voice/voice_settings_page.dart                                            # ElevenLabs gating
lib/voice/voice_provider.dart                                                 # wake word gating

test/features/settings/ai_model_provider_test.dart                           # update default
```

---

## Task 1: Add `purchases_flutter` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add `purchases_flutter` under `dependencies`**

Open `pubspec.yaml`. Under the `dependencies:` block, after `shared_preferences: ^2.3.2`, add:

```yaml
  # Subscription
  purchases_flutter: ^8.0.0
```

- [ ] **Step 2: Fetch the package**

```bash
cd /Users/upkarsingh/nivara
flutter pub get
```

Expected: output ends with `Got dependencies!` and no errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/upkarsingh/nivara
git add pubspec.yaml pubspec.lock
git commit -m "chore: add purchases_flutter for RevenueCat"
```

---

## Task 2: `SubscriptionTier` enum + `TierConfig`

**Files:**
- Create: `lib/features/subscription/domain/subscription_tier.dart`
- Create: `test/features/subscription/domain/tier_config_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/subscription/domain/tier_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/domain/subscription_tier.dart';

void main() {
  group('TierConfig.forTier', () {
    test('free tier has correct limits', () {
      final cfg = TierConfig.forTier(SubscriptionTier.free);
      expect(cfg.monthlyBudgetUsd, 0.15);
      expect(cfg.defaultModel, 'gemini_flash');
      expect(cfg.historyDays, 7);
      expect(cfg.musicEnabled, false);
      expect(cfg.wakeWordLimit, 5);
      expect(cfg.wakeWordLimitIsMonthly, false);
      expect(cfg.elevenLabsEnabled, false);
      expect(cfg.modelOverrideAllowed, false);
      expect(cfg.availableModels, ['gemini_flash']);
    });

    test('pro tier has correct limits', () {
      final cfg = TierConfig.forTier(SubscriptionTier.pro);
      expect(cfg.monthlyBudgetUsd, 1.00);
      expect(cfg.defaultModel, 'gemini_flash');
      expect(cfg.historyDays, null); // unlimited
      expect(cfg.musicEnabled, true);
      expect(cfg.wakeWordLimit, 30);
      expect(cfg.wakeWordLimitIsMonthly, true);
      expect(cfg.elevenLabsEnabled, false);
      expect(cfg.modelOverrideAllowed, true);
      expect(cfg.availableModels,
          ['gemini_flash', 'gpt4o_mini', 'claude_haiku']);
    });

    test('premium tier has correct limits', () {
      final cfg = TierConfig.forTier(SubscriptionTier.premium);
      expect(cfg.monthlyBudgetUsd, 9.00);
      expect(cfg.historyDays, null);
      expect(cfg.musicEnabled, true);
      expect(cfg.wakeWordLimit, null); // unlimited
      expect(cfg.elevenLabsEnabled, true);
      expect(cfg.modelOverrideAllowed, true);
      expect(cfg.availableModels, [
        'gemini_flash',
        'gpt4o_mini',
        'claude_haiku',
        'claude_sonnet',
        'gpt4o',
      ]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/domain/tier_config_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `subscription_tier.dart`**

Create `lib/features/subscription/domain/subscription_tier.dart`:

```dart
enum SubscriptionTier { free, pro, premium }

/// Immutable config for a subscription tier.
class TierConfig {
  const TierConfig({
    required this.monthlyBudgetUsd,
    required this.defaultModel,
    required this.historyDays,
    required this.musicEnabled,
    required this.wakeWordLimit,
    required this.wakeWordLimitIsMonthly,
    required this.elevenLabsEnabled,
    required this.modelOverrideAllowed,
    required this.availableModels,
  });

  /// Monthly AI spend budget in USD.
  final double monthlyBudgetUsd;

  /// Model ID used when no override is active.
  final String defaultModel;

  /// Days of chat history retained. `null` = unlimited.
  final int? historyDays;

  final bool musicEnabled;

  /// Max wake word activations. `null` = unlimited.
  final int? wakeWordLimit;

  /// `true` → limit resets monthly (Pro). `false` → lifetime total (Free).
  final bool wakeWordLimitIsMonthly;

  final bool elevenLabsEnabled;
  final bool modelOverrideAllowed;

  /// Ordered list of model IDs the user may select.
  final List<String> availableModels;

  static TierConfig forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return const TierConfig(
          monthlyBudgetUsd: 0.15,
          defaultModel: 'gemini_flash',
          historyDays: 7,
          musicEnabled: false,
          wakeWordLimit: 5,
          wakeWordLimitIsMonthly: false,
          elevenLabsEnabled: false,
          modelOverrideAllowed: false,
          availableModels: ['gemini_flash'],
        );
      case SubscriptionTier.pro:
        return const TierConfig(
          monthlyBudgetUsd: 1.00,
          defaultModel: 'gemini_flash',
          historyDays: null,
          musicEnabled: true,
          wakeWordLimit: 30,
          wakeWordLimitIsMonthly: true,
          elevenLabsEnabled: false,
          modelOverrideAllowed: true,
          availableModels: ['gemini_flash', 'gpt4o_mini', 'claude_haiku'],
        );
      case SubscriptionTier.premium:
        return const TierConfig(
          monthlyBudgetUsd: 9.00,
          defaultModel: 'gemini_flash',
          historyDays: null,
          musicEnabled: true,
          wakeWordLimit: null,
          wakeWordLimitIsMonthly: true,
          elevenLabsEnabled: true,
          modelOverrideAllowed: true,
          availableModels: [
            'gemini_flash',
            'gpt4o_mini',
            'claude_haiku',
            'claude_sonnet',
            'gpt4o',
          ],
        );
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/domain/tier_config_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/domain/subscription_tier.dart \
        test/features/subscription/domain/tier_config_test.dart
git commit -m "feat(subscription): add SubscriptionTier enum and TierConfig"
```

---

## Task 3: `ModelBudget` utility

**Files:**
- Create: `lib/features/subscription/domain/model_budget.dart`
- Create: `test/features/subscription/domain/model_budget_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/subscription/domain/model_budget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/domain/model_budget.dart';

void main() {
  group('ModelBudget', () {
    test('costPerMessage returns correct cost for gemini_flash', () {
      expect(ModelBudget.costPerMessage('gemini_flash'), 0.00005);
    });

    test('costPerMessage returns correct cost for gpt4o_mini', () {
      expect(ModelBudget.costPerMessage('gpt4o_mini'), 0.00012);
    });

    test('costPerMessage returns correct cost for claude_haiku', () {
      expect(ModelBudget.costPerMessage('claude_haiku'), 0.0006);
    });

    test('costPerMessage returns correct cost for claude_sonnet', () {
      expect(ModelBudget.costPerMessage('claude_sonnet'), 0.006);
    });

    test('costPerMessage returns correct cost for gpt4o', () {
      expect(ModelBudget.costPerMessage('gpt4o'), 0.005);
    });

    test('costPerMessage falls back to gemini_flash cost for unknown model', () {
      expect(ModelBudget.costPerMessage('unknown_model'), 0.00005);
    });

    test('messagesPerMonth for gemini_flash on free budget (~3000)', () {
      // $0.15 / $0.00005 = 3000
      expect(ModelBudget.messagesPerMonth(budgetUsd: 0.15, model: 'gemini_flash'), 3000);
    });

    test('messagesPerMonth for gemini_flash on pro budget (~20000)', () {
      // $1.00 / $0.00005 = 20000
      expect(ModelBudget.messagesPerMonth(budgetUsd: 1.00, model: 'gemini_flash'), 20000);
    });

    test('messagesPerMonth for claude_haiku on pro budget (~1666)', () {
      // $1.00 / $0.0006 = 1666
      expect(ModelBudget.messagesPerMonth(budgetUsd: 1.00, model: 'claude_haiku'), 1666);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/domain/model_budget_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `model_budget.dart`**

Create `lib/features/subscription/domain/model_budget.dart`:

```dart
/// Cost and quota calculations based on AI model and tier budget.
///
/// Costs are per message assuming ~800 tokens average
/// (400 input + 400 output).
class ModelBudget {
  ModelBudget._();

  static const _costs = <String, double>{
    'gemini_flash': 0.00005,
    'gpt4o_mini': 0.00012,
    'claude_haiku': 0.0006,
    'claude_sonnet': 0.006,
    'gpt4o': 0.005,
  };

  /// Cost per message in USD for [model].
  /// Falls back to `gemini_flash` cost for unknown model IDs.
  static double costPerMessage(String model) =>
      _costs[model] ?? _costs['gemini_flash']!;

  /// Number of messages the user can send per month given [budgetUsd]
  /// and [model]. Always at least 1.
  static int messagesPerMonth({
    required double budgetUsd,
    required String model,
  }) {
    final cost = costPerMessage(model);
    return (budgetUsd / cost).floor().clamp(1, 999999);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/domain/model_budget_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/domain/model_budget.dart \
        test/features/subscription/domain/model_budget_test.dart
git commit -m "feat(subscription): add ModelBudget cost/quota utility"
```

---

## Task 4: `RevenueCatService` abstract interface + stub

**Files:**
- Create: `lib/features/subscription/data/revenue_cat_service.dart`

No unit test for this task — `RevenueCatServiceStub` is exercised via `subscriptionProvider` tests in Task 8.

- [ ] **Step 1: Create `revenue_cat_service.dart`**

```dart
import '../domain/subscription_tier.dart';

/// Abstract interface for RevenueCat operations.
/// Allows swapping in [RevenueCatServiceStub] during development/testing.
abstract class RevenueCatService {
  Future<void> init(String apiKey);
  Future<SubscriptionTier> getCurrentTier();
  Future<void> restorePurchases();
}

/// Stub always returns [SubscriptionTier.free].
/// Used until real RevenueCat products are set up in Task 15.
class RevenueCatServiceStub implements RevenueCatService {
  @override
  Future<void> init(String apiKey) async {}

  @override
  Future<SubscriptionTier> getCurrentTier() async => SubscriptionTier.free;

  @override
  Future<void> restorePurchases() async {}
}

/// Plain Riverpod provider — returns stub until overridden in main().
import 'package:flutter_riverpod/flutter_riverpod.dart';

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (_) => RevenueCatServiceStub(),
);
```

> **Note:** The import for `flutter_riverpod` must be at the top of the file, not inside the body. Reorganise as two separate blocks (domain import first, then package imports):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/subscription_tier.dart';

/// Abstract interface for RevenueCat operations.
abstract class RevenueCatService {
  Future<void> init(String apiKey);
  Future<SubscriptionTier> getCurrentTier();
  Future<void> restorePurchases();
}

/// Stub always returns [SubscriptionTier.free].
class RevenueCatServiceStub implements RevenueCatService {
  @override Future<void> init(String apiKey) async {}
  @override Future<SubscriptionTier> getCurrentTier() async => SubscriptionTier.free;
  @override Future<void> restorePurchases() async {}
}

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (_) => RevenueCatServiceStub(),
);
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/upkarsingh/nivara
flutter analyze lib/features/subscription/data/revenue_cat_service.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/data/revenue_cat_service.dart
git commit -m "feat(subscription): add RevenueCatService interface + stub provider"
```

---

## Task 5: `QuotaDoc` + `QuotaRepository`

**Files:**
- Create: `lib/features/subscription/data/quota_repository.dart`
- Create: `test/features/subscription/domain/quota_state_test.dart`

The test covers pure `QuotaDoc` parsing and `QuotaState` logic (no Firestore in unit tests — Firestore operations need integration tests with an emulator).

- [ ] **Step 1: Write the failing test**

Create `test/features/subscription/domain/quota_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/data/quota_repository.dart';

void main() {
  group('QuotaDoc', () {
    test('fromMap parses correctly', () {
      final doc = QuotaDoc.fromMap({
        'messagesUsed': 150,
        'graceUsed': 1,
        'periodStart': '2026-05-01T00:00:00.000',
        'model': 'gemini_flash',
      });
      expect(doc.messagesUsed, 150);
      expect(doc.graceUsed, 1);
      expect(doc.model, 'gemini_flash');
    });

    test('fromMap defaults missing fields to zero', () {
      final doc = QuotaDoc.fromMap({});
      expect(doc.messagesUsed, 0);
      expect(doc.graceUsed, 0);
      expect(doc.model, 'gemini_flash');
    });
  });

  group('QuotaDoc period check', () {
    test('isNewPeriod returns false when within 30 days', () {
      final recent = DateTime.now().subtract(const Duration(days: 15));
      final doc = QuotaDoc(
        messagesUsed: 0,
        graceUsed: 0,
        periodStart: recent,
        model: 'gemini_flash',
      );
      expect(doc.isNewPeriod, false);
    });

    test('isNewPeriod returns true when 30+ days elapsed', () {
      final old = DateTime.now().subtract(const Duration(days: 31));
      final doc = QuotaDoc(
        messagesUsed: 0,
        graceUsed: 0,
        periodStart: old,
        model: 'gemini_flash',
      );
      expect(doc.isNewPeriod, true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/domain/quota_state_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `quota_repository.dart`**

Create `lib/features/subscription/data/quota_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Value object
// ---------------------------------------------------------------------------

class QuotaDoc {
  const QuotaDoc({
    required this.messagesUsed,
    required this.graceUsed,
    required this.periodStart,
    required this.model,
  });

  final int messagesUsed;
  final int graceUsed;
  final DateTime periodStart;
  final String model;

  /// True when 30+ days have elapsed since [periodStart].
  bool get isNewPeriod =>
      DateTime.now().difference(periodStart).inDays >= 30;

  factory QuotaDoc.fromMap(Map<String, dynamic> map) {
    final periodRaw = map['periodStart'] as String?;
    return QuotaDoc(
      messagesUsed: (map['messagesUsed'] as int?) ?? 0,
      graceUsed: (map['graceUsed'] as int?) ?? 0,
      periodStart: periodRaw != null
          ? DateTime.tryParse(periodRaw) ?? DateTime.now()
          : DateTime.now(),
      model: (map['model'] as String?) ?? 'gemini_flash',
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class QuotaRepository {
  QuotaRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _doc = firestore.collection('users').doc(uid).collection('quota').doc('current');

  final DocumentReference<Map<String, dynamic>> _doc;

  /// Emits a [QuotaDoc] whenever the Firestore document changes.
  Stream<QuotaDoc> getQuota() => _doc.snapshots().map((snap) {
        if (!snap.exists) {
          return QuotaDoc(
            messagesUsed: 0,
            graceUsed: 0,
            periodStart: DateTime.now(),
            model: 'gemini_flash',
          );
        }
        return QuotaDoc.fromMap(snap.data()!);
      });

  /// Creates or resets the quota document if >30 days have passed.
  Future<void> resetIfNewPeriod() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      await _doc.set(_freshDoc());
      return;
    }
    final current = QuotaDoc.fromMap(snap.data()!);
    if (current.isNewPeriod) {
      await _doc.update({
        'messagesUsed': 0,
        'graceUsed': 0,
        'periodStart': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> incrementMessage() =>
      _doc.update({'messagesUsed': FieldValue.increment(1)});

  Future<void> incrementGrace() =>
      _doc.update({'graceUsed': FieldValue.increment(1)});

  Future<void> setModel(String model) =>
      _doc.update({'model': model});

  Map<String, dynamic> _freshDoc() => {
        'messagesUsed': 0,
        'graceUsed': 0,
        'periodStart': DateTime.now().toIso8601String(),
        'model': 'gemini_flash',
      };
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final quotaRepositoryProvider = Provider<QuotaRepository>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('No authenticated user');
  return QuotaRepository(
    firestore: FirebaseFirestore.instance,
    uid: user.uid,
  );
});
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/domain/quota_state_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/data/quota_repository.dart \
        test/features/subscription/domain/quota_state_test.dart
git commit -m "feat(subscription): add QuotaDoc, QuotaRepository, and plain provider"
```

---

## Task 6: `WakeWordQuotaRepository`

**Files:**
- Create: `lib/features/subscription/data/wake_word_quota_repository.dart`

No separate test: the logic mirrors `QuotaRepository` and the gating is tested as part of `voice_provider` tests in Task 16.

- [ ] **Step 1: Create `wake_word_quota_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WakeWordUsageDoc {
  const WakeWordUsageDoc({
    required this.activationsUsed,
    required this.periodStart,
  });

  final int activationsUsed;
  final DateTime periodStart;

  bool get isNewPeriod =>
      DateTime.now().difference(periodStart).inDays >= 30;

  factory WakeWordUsageDoc.fromMap(Map<String, dynamic> map) {
    final raw = map['periodStart'] as String?;
    return WakeWordUsageDoc(
      activationsUsed: (map['activationsUsed'] as int?) ?? 0,
      periodStart: raw != null
          ? DateTime.tryParse(raw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class WakeWordQuotaRepository {
  WakeWordQuotaRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _doc = firestore
            .collection('users')
            .doc(uid)
            .collection('wakeWordUsage')
            .doc('current');

  final DocumentReference<Map<String, dynamic>> _doc;

  Future<WakeWordUsageDoc> get() async {
    final snap = await _doc.get();
    if (!snap.exists) return _fresh();
    return WakeWordUsageDoc.fromMap(snap.data()!);
  }

  Future<void> increment() async {
    final usage = await get();
    if (usage.isNewPeriod) {
      await _doc.set({
        'activationsUsed': 1,
        'periodStart': DateTime.now().toIso8601String(),
      });
    } else {
      await _doc.set(
        {'activationsUsed': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    }
  }

  WakeWordUsageDoc _fresh() => WakeWordUsageDoc(
        activationsUsed: 0,
        periodStart: DateTime.now(),
      );
}

final wakeWordQuotaRepositoryProvider = Provider<WakeWordQuotaRepository>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('No authenticated user');
  return WakeWordQuotaRepository(
    firestore: FirebaseFirestore.instance,
    uid: user.uid,
  );
});
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/upkarsingh/nivara
flutter analyze lib/features/subscription/data/wake_word_quota_repository.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/data/wake_word_quota_repository.dart
git commit -m "feat(subscription): add WakeWordQuotaRepository"
```

---

## Task 7: `QuotaState` + three Riverpod providers

**Files:**
- Create: `lib/features/subscription/presentation/providers/subscription_provider.dart`
- Create: `test/features/subscription/presentation/quota_state_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/subscription/presentation/quota_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/data/quota_repository.dart';
import 'package:nivara/features/subscription/presentation/providers/subscription_provider.dart';

void main() {
  group('QuotaState.fromDoc', () {
    QuotaDoc _doc({int messagesUsed = 0, int graceUsed = 0}) => QuotaDoc(
          messagesUsed: messagesUsed,
          graceUsed: graceUsed,
          periodStart: DateTime.now(),
          model: 'gemini_flash',
        );

    test('normal — not in grace, not exhausted', () {
      final state = QuotaState.fromDoc(
        doc: _doc(messagesUsed: 100),
        monthlyQuota: 3000,
      );
      expect(state.remaining, 2900);
      expect(state.inGrace, false);
      expect(state.exhausted, false);
    });

    test('inGrace when remaining <= 0 and graceUsed < 3', () {
      final state = QuotaState.fromDoc(
        doc: _doc(messagesUsed: 3000, graceUsed: 1),
        monthlyQuota: 3000,
      );
      expect(state.remaining, 0);
      expect(state.inGrace, true);
      expect(state.exhausted, false);
      expect(state.graceRemaining, 2);
    });

    test('exhausted when remaining <= 0 and graceUsed >= 3', () {
      final state = QuotaState.fromDoc(
        doc: _doc(messagesUsed: 3000, graceUsed: 3),
        monthlyQuota: 3000,
      );
      expect(state.inGrace, false);
      expect(state.exhausted, true);
      expect(state.graceRemaining, 0);
    });

    test('remaining can be negative (over-quota scenario)', () {
      final state = QuotaState.fromDoc(
        doc: _doc(messagesUsed: 3050, graceUsed: 2),
        monthlyQuota: 3000,
      );
      expect(state.remaining, -50);
      expect(state.inGrace, true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/presentation/quota_state_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `subscription_provider.dart`**

Create `lib/features/subscription/presentation/providers/subscription_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/settings/presentation/providers/ai_model_provider.dart';
import '../../data/quota_repository.dart';
import '../../data/revenue_cat_service.dart';
import '../../domain/model_budget.dart';
import '../../domain/subscription_tier.dart';

// ---------------------------------------------------------------------------
// QuotaState
// ---------------------------------------------------------------------------

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

  /// Computed from tier budget ÷ model cost.
  final int monthlyQuota;

  /// `monthlyQuota - messagesUsed`. Can be negative during grace.
  final int remaining;

  /// 0–3 grace messages used.
  final int graceUsed;

  /// `remaining <= 0 && graceUsed < 3`.
  final bool inGrace;

  /// `remaining <= 0 && graceUsed >= 3` — hard block.
  final bool exhausted;

  /// `3 - graceUsed`.
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
}

// ---------------------------------------------------------------------------
// subscriptionProvider
// ---------------------------------------------------------------------------

/// Reads the active RevenueCat entitlement.
/// Invalidated after purchase / restore by calling `ref.invalidate(subscriptionProvider)`.
final subscriptionProvider = FutureProvider<SubscriptionTier>((ref) async {
  return ref.read(revenueCatServiceProvider).getCurrentTier();
});

// ---------------------------------------------------------------------------
// tierConfigProvider
// ---------------------------------------------------------------------------

/// Synchronous config for the current tier. Defaults to Free on loading/error.
final tierConfigProvider = Provider<TierConfig>((ref) {
  final tier =
      ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;
  return TierConfig.forTier(tier);
});

// ---------------------------------------------------------------------------
// quotaProvider
// ---------------------------------------------------------------------------

/// Streams [QuotaState] by combining tier, model, and Firestore quota doc.
/// Re-runs automatically when subscription or model changes.
final quotaProvider = StreamProvider<QuotaState>((ref) async* {
  final tier =
      ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;
  final model =
      ref.watch(aiModelNotifierProvider).valueOrNull ?? 'gemini_flash';
  final tierConfig = TierConfig.forTier(tier);
  final monthlyQuota = ModelBudget.messagesPerMonth(
    budgetUsd: tierConfig.monthlyBudgetUsd,
    model: model,
  );

  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return;

  final repo = ref.read(quotaRepositoryProvider);
  await repo.resetIfNewPeriod();

  await for (final doc in repo.getQuota()) {
    yield QuotaState.fromDoc(doc: doc, monthlyQuota: monthlyQuota);
  }
});
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/presentation/quota_state_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/presentation/providers/subscription_provider.dart \
        test/features/subscription/presentation/quota_state_test.dart
git commit -m "feat(subscription): add QuotaState, subscriptionProvider, tierConfigProvider, quotaProvider"
```

---

## Task 8: Update `ai_model_provider.dart` — new model IDs + default

**Files:**
- Modify: `lib/features/settings/presentation/providers/ai_model_provider.dart`
- Modify: `test/features/settings/ai_model_provider_test.dart`

- [ ] **Step 1: Update the test first (RED)**

Open `test/features/settings/ai_model_provider_test.dart`. Change every occurrence of `'claude'` (the default) to `'gemini_flash'`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('aiModelNotifierProvider defaults to gemini_flash', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(aiModelNotifierProvider.future);
    expect(value, 'gemini_flash');
  });

  test('setModel persists to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(aiModelNotifierProvider.future);
    await container.read(aiModelNotifierProvider.notifier).setModel('gpt4o_mini');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_ai_model'), 'gpt4o_mini');
  });

  test('aiModelNotifierProvider loads persisted value', () async {
    SharedPreferences.setMockInitialValues({'selected_ai_model': 'claude_haiku'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(aiModelNotifierProvider.future);
    expect(value, 'claude_haiku');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/settings/ai_model_provider_test.dart
```

Expected: FAIL — `expected 'gemini_flash' but was 'claude'`.

- [ ] **Step 3: Update `ai_model_provider.dart`**

Replace the entire file content with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'selected_ai_model';

/// Canonical model IDs — match what the Hermes backend accepts as `ai_model`.
const kModelGeminiFlash = 'gemini_flash';
const kModelGpt4oMini = 'gpt4o_mini';
const kModelClaudeHaiku = 'claude_haiku';
const kModelClaudeSonnet = 'claude_sonnet';
const kModelGpt4o = 'gpt4o';

/// Default model for all tiers — cheapest, gives the most messages/month.
const kDefaultModel = kModelGeminiFlash;

class AiModelNotifier extends AsyncNotifier<String> {
  late SharedPreferences _prefs;

  @override
  Future<String> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _prefs.getString(_prefsKey) ?? kDefaultModel;
  }

  Future<void> setModel(String model) async {
    await _prefs.setString(_prefsKey, model);
    state = AsyncData(model);
  }
}

final aiModelNotifierProvider =
    AsyncNotifierProvider<AiModelNotifier, String>(AiModelNotifier.new);
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/settings/ai_model_provider_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
cd /Users/upkarsingh/nivara
flutter test --reporter compact
```

Expected: all tests pass (the old 'claude' default references may break other tests — fix any that fail by replacing `'claude'` with `'gemini_flash'` where the test was checking for the default model).

- [ ] **Step 6: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/settings/presentation/providers/ai_model_provider.dart \
        test/features/settings/ai_model_provider_test.dart
git commit -m "feat(settings): update model IDs to new names, default to gemini_flash"
```

---

## Task 9: `PaywallSheet` widget

**Files:**
- Create: `lib/features/subscription/presentation/widgets/paywall_sheet.dart`
- Create: `test/features/subscription/presentation/paywall_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/subscription/presentation/paywall_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/data/revenue_cat_service.dart';
import 'package:nivara/features/subscription/domain/subscription_tier.dart';
import 'package:nivara/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:nivara/features/subscription/presentation/widgets/paywall_sheet.dart';

Widget _buildSheet() {
  return ProviderScope(
    overrides: [
      revenueCatServiceProvider.overrideWithValue(RevenueCatServiceStub()),
      subscriptionProvider.overrideWith((_) async => SubscriptionTier.free),
    ],
    child: const MaterialApp(
      home: Scaffold(body: PaywallSheet()),
    ),
  );
}

void main() {
  testWidgets('PaywallSheet shows three tier cards', (tester) async {
    await tester.pumpWidget(_buildSheet());
    await tester.pump();

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('PaywallSheet shows upgrade buttons for Pro and Premium',
      (tester) async {
    await tester.pumpWidget(_buildSheet());
    await tester.pump();

    expect(find.text('Upgrade to Pro'), findsOneWidget);
    expect(find.text('Upgrade to Premium'), findsOneWidget);
  });

  testWidgets('PaywallSheet shows Restore Purchases link', (tester) async {
    await tester.pumpWidget(_buildSheet());
    await tester.pump();

    expect(find.text('Restore Purchases'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/presentation/paywall_sheet_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `paywall_sheet.dart`**

Create `lib/features/subscription/presentation/widgets/paywall_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_provider.dart';
import '../../data/revenue_cat_service.dart';

class PaywallSheet extends ConsumerWidget {
  const PaywallSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Unlock Nivara',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a plan to keep chatting',
              style: TextStyle(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _TierCard(
              name: 'Free',
              price: 'Free',
              features: const [
                '~3,000 messages/month',
                '7 days chat history',
                '5 wake word trials',
              ],
              ctaLabel: null, // current plan
            ),
            const SizedBox(height: 12),
            _TierCard(
              name: 'Pro',
              price: '\$7.99/month',
              features: const [
                '~20,000 messages/month',
                'Unlimited history',
                'Music playback',
                '30 wake word activations/month',
                'GPT-4o Mini + Claude Haiku',
              ],
              ctaLabel: 'Upgrade to Pro',
              onTap: () => _purchase(context, ref, 'pro'),
            ),
            const SizedBox(height: 12),
            _TierCard(
              name: 'Premium',
              price: '\$19.99/month',
              features: const [
                '~180,000 messages/month',
                'Everything in Pro',
                'ElevenLabs TTS',
                'Unlimited wake word',
                'All 5 AI models',
              ],
              ctaLabel: 'Upgrade to Premium',
              onTap: () => _purchase(context, ref, 'premium'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _restore(context, ref),
              child: const Text('Restore Purchases'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(
      BuildContext context, WidgetRef ref, String planId) async {
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
      ref.invalidate(subscriptionProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase failed, please try again')),
        );
      }
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
      ref.invalidate(subscriptionProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed, please try again')),
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
    this.onTap,
  });

  final String name;
  final String price;
  final List<String> features;
  final String? ctaLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: ctaLabel == null
              ? Colors.white24
              : const Color(0xFF6366F1),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(price,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $f',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              )),
          if (ctaLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                ),
                child: Text(ctaLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/presentation/paywall_sheet_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/presentation/widgets/paywall_sheet.dart \
        test/features/subscription/presentation/paywall_sheet_test.dart
git commit -m "feat(subscription): add PaywallSheet bottom sheet with tier cards"
```

---

## Task 10: `QuotaBanner` + `QuotaIndicator` widgets

**Files:**
- Create: `lib/features/subscription/presentation/widgets/quota_banner.dart`
- Create: `lib/features/subscription/presentation/widgets/quota_indicator.dart`
- Create: `test/features/subscription/presentation/quota_banner_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/subscription/presentation/quota_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:nivara/features/subscription/presentation/widgets/quota_banner.dart';

QuotaState _makeState({bool inGrace = false, bool exhausted = false, int graceRemaining = 3}) {
  return QuotaState(
    messagesUsed: inGrace || exhausted ? 3000 : 100,
    monthlyQuota: 3000,
    remaining: inGrace || exhausted ? 0 : 2900,
    graceUsed: 3 - graceRemaining,
    inGrace: inGrace,
    exhausted: exhausted,
    graceRemaining: graceRemaining,
  );
}

Widget _wrap(QuotaState state) => ProviderScope(
      overrides: [
        quotaProvider.overrideWith((_) => Stream.value(state)),
      ],
      child: const MaterialApp(home: Scaffold(body: QuotaBanner())),
    );

void main() {
  testWidgets('QuotaBanner is hidden when not in grace', (tester) async {
    await tester.pumpWidget(_wrap(_makeState()));
    await tester.pump();
    expect(find.byType(QuotaBanner), findsOneWidget);
    // Banner content should not be visible when not in grace
    expect(find.textContaining('grace'), findsNothing);
  });

  testWidgets('QuotaBanner shows grace message count when inGrace', (tester) async {
    await tester.pumpWidget(_wrap(_makeState(inGrace: true, graceRemaining: 2)));
    await tester.pump();
    expect(find.textContaining('2 grace'), findsOneWidget);
  });

  testWidgets('QuotaBanner shows Upgrade button when inGrace', (tester) async {
    await tester.pumpWidget(_wrap(_makeState(inGrace: true, graceRemaining: 1)));
    await tester.pump();
    expect(find.text('Upgrade'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/presentation/quota_banner_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement `quota_banner.dart`**

Create `lib/features/subscription/presentation/widgets/quota_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_provider.dart';
import 'paywall_sheet.dart';

/// Amber banner shown inside ChatPage when the user is in the grace window.
/// Hidden when quota is healthy or when exhausted (paywall sheet takes over).
class QuotaBanner extends ConsumerWidget {
  const QuotaBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(quotaProvider);
    final quotaState = quotaAsync.valueOrNull;
    if (quotaState == null || !quotaState.inGrace) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.amber.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "You've used all your messages. "
              "${quotaState.graceRemaining} grace "
              "${quotaState.graceRemaining == 1 ? 'message' : 'messages'} remaining.",
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const PaywallSheet(),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `quota_indicator.dart`**

Create `lib/features/subscription/presentation/widgets/quota_indicator.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subscription_tier.dart';
import '../providers/subscription_provider.dart';

/// Subtle message counter shown below the chat input on the Free tier only.
/// Turns red when fewer than 50 messages remain.
class QuotaIndicator extends ConsumerWidget {
  const QuotaIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(tierConfigProvider);
    // Only visible on Free tier
    if (tier.modelOverrideAllowed) return const SizedBox.shrink();

    final quotaAsync = ref.watch(quotaProvider);
    final state = quotaAsync.valueOrNull;
    if (state == null) return const SizedBox.shrink();

    final isLow = state.remaining < 50;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '${_fmt(state.messagesUsed)} / ${_fmt(state.monthlyQuota)} messages this month',
        style: TextStyle(
          fontSize: 11,
          color: isLow ? Colors.redAccent : Colors.white38,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/subscription/presentation/quota_banner_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/presentation/widgets/quota_banner.dart \
        lib/features/subscription/presentation/widgets/quota_indicator.dart \
        test/features/subscription/presentation/quota_banner_test.dart
git commit -m "feat(subscription): add QuotaBanner and QuotaIndicator widgets"
```

---

## Task 11: Update `ModelSelectorWidget` — tier-aware locking + quota labels

**Files:**
- Modify: `lib/features/settings/presentation/widgets/model_selector_widget.dart`

No new test file — update the manual QA pattern. The widget is already tested via `voice_settings_page_test.dart`; functional correctness is verified by running the app.

- [ ] **Step 1: Replace `model_selector_widget.dart`**

Replace the entire file with:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../subscription/domain/model_budget.dart';
import '../../../subscription/domain/subscription_tier.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../providers/ai_model_provider.dart';

/// Display name, subtitle, and model ID for each available model.
const _modelMeta = [
  (id: kModelGeminiFlash, label: 'Gemini 2.0 Flash', subtitle: 'default — most messages'),
  (id: kModelGpt4oMini, label: 'GPT-4o Mini', subtitle: 'better for research'),
  (id: kModelClaudeHaiku, label: 'Claude Haiku 3.5', subtitle: 'best writing quality'),
  (id: kModelClaudeSonnet, label: 'Claude Sonnet', subtitle: 'deepest reasoning'),
  (id: kModelGpt4o, label: 'GPT-4o', subtitle: 'deepest reasoning'),
];

class ModelSelectorWidget extends ConsumerWidget {
  const ModelSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(aiModelNotifierProvider);
    final tierConfig = ref.watch(tierConfigProvider);

    return modelAsync.when(
      loading: () => const CircularProgressIndicator.adaptive(),
      error: (e, _) => Text('Error: $e'),
      data: (selected) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Callout text
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Gemini Flash gives you the most messages. '
              'Switch to another model when you need deeper research '
              'or higher quality responses.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          ..._modelMeta.map((meta) {
            final isAvailable = tierConfig.availableModels.contains(meta.id);
            final quota = ModelBudget.messagesPerMonth(
              budgetUsd: tierConfig.monthlyBudgetUsd,
              model: meta.id,
            );
            final quotaLabel = _formatQuota(quota);

            return RadioListTile<String>(
              value: meta.id,
              groupValue: selected,
              title: Row(
                children: [
                  Text(meta.label),
                  if (!isAvailable) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.lock_outline,
                        size: 14, color: Colors.white38),
                  ],
                ],
              ),
              subtitle: Text(
                isAvailable
                    ? '~$quotaLabel msgs/month · ${meta.subtitle}'
                    : 'Upgrade to unlock',
                style: TextStyle(
                  color: isAvailable ? Colors.white54 : Colors.white30,
                  fontSize: 12,
                ),
              ),
              onChanged: isAvailable
                  ? (v) {
                      if (v != null) {
                        unawaited(
                          ref
                              .read(aiModelNotifierProvider.notifier)
                              .setModel(v),
                        );
                      }
                    }
                  : null, // disabled
            );
          }),
        ],
      ),
    );
  }

  String _formatQuota(int n) {
    if (n >= 1000) return '~${(n / 1000).round()}k';
    return '$n';
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/upkarsingh/nivara
flutter analyze lib/features/settings/presentation/widgets/model_selector_widget.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Run full tests**

```bash
cd /Users/upkarsingh/nivara
flutter test --reporter compact
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/settings/presentation/widgets/model_selector_widget.dart
git commit -m "feat(settings): update ModelSelectorWidget with tier-aware locking and quota labels"
```

---

## Task 12: Chat integration — quota tracking in `ChatNotifier`

**Files:**
- Modify: `lib/features/chat/presentation/providers/chat_provider.dart`
- Create: `test/features/chat/chat_provider_quota_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/chat/chat_provider_quota_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';
import 'package:nivara/features/chat/presentation/providers/chat_provider.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/presentation/providers/mood_playlist_provider.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';
import 'package:nivara/features/profile/presentation/providers/profile_provider.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';
import 'package:nivara/features/subscription/data/quota_repository.dart';
import 'package:nivara/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:nivara/shared/models/user_profile.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHermesClient extends HermesClient {
  _FakeHermesClient() : super(baseUrl: 'http://localhost');

  @override
  Stream<ChatChunk> chatStream({
    required List<Map<String, String>> messages,
    required String assistantName,
    String aiModel = 'gemini_flash',
  }) async* {
    yield const TextChunk('Hello');
    yield const DoneChunk();
  }
}

class _FakeAiModel extends AiModelNotifier {
  @override
  Future<String> build() async => 'gemini_flash';
}

class _EmptyMusicNotifier extends MusicPlayerNotifier {
  @override
  MusicPlayerState build() => const MusicPlayerState();
}

// Quota repository that records calls
class _RecordingQuotaRepo extends QuotaRepository {
  _RecordingQuotaRepo()
      : super(firestore: null as dynamic, uid: 'test-uid');

  int messageIncrements = 0;
  int graceIncrements = 0;

  @override
  Stream<QuotaDoc> getQuota() => const Stream.empty();

  @override
  Future<void> resetIfNewPeriod() async {}

  @override
  Future<void> incrementMessage() async => messageIncrements++;

  @override
  Future<void> incrementGrace() async => graceIncrements++;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({
  required _RecordingQuotaRepo repo,
  bool exhausted = false,
  bool inGrace = false,
  int graceRemaining = 3,
}) {
  final quotaState = QuotaState(
    messagesUsed: exhausted || inGrace ? 3000 : 100,
    monthlyQuota: 3000,
    remaining: exhausted || inGrace ? 0 : 2900,
    graceUsed: exhausted ? 3 : inGrace ? 1 : 0,
    inGrace: inGrace,
    exhausted: exhausted,
    graceRemaining: graceRemaining,
  );
  return ProviderContainer(
    overrides: [
      hermesClientProvider.overrideWithValue(_FakeHermesClient()),
      moodToneProvider.overrideWith((_) async => null),
      assistantConfigProvider.overrideWith(
          (_) async => const AssistantConfig(name: 'Rocky', voice: 'neutral', speed: 'normal')),
      aiModelNotifierProvider.overrideWith(_FakeAiModel.new),
      moodPlaylistProvider.overrideWith((_) async => null),
      musicPlayerNotifierProvider.overrideWith(_EmptyMusicNotifier.new),
      quotaRepositoryProvider.overrideWithValue(repo),
      quotaProvider.overrideWith((_) => Stream.value(quotaState)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('sendMessage increments messagesUsed on normal send', () async {
    final repo = _RecordingQuotaRepo();
    final container = _makeContainer(repo: repo);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('hello');

    expect(repo.messageIncrements, 1);
    expect(repo.graceIncrements, 0);
  });

  test('sendMessage increments graceUsed when inGrace', () async {
    final repo = _RecordingQuotaRepo();
    final container = _makeContainer(repo: repo, inGrace: true, graceRemaining: 2);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('hello');

    expect(repo.graceIncrements, 1);
    expect(repo.messageIncrements, 0);
  });

  test('sendMessage does nothing when exhausted', () async {
    final repo = _RecordingQuotaRepo();
    final container = _makeContainer(repo: repo, exhausted: true);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('hello');

    expect(repo.messageIncrements, 0);
    expect(repo.graceIncrements, 0);
    // State should be unchanged (no assistant message appended)
    expect(container.read(chatNotifierProvider).length, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/chat/chat_provider_quota_test.dart
```

Expected: FAIL — missing imports / `quotaProvider` not used in notifier.

- [ ] **Step 3: Update `chat_provider.dart` — add quota integration**

Add the following imports to the top of `lib/features/chat/presentation/providers/chat_provider.dart` (after the existing imports):

```dart
import '../../../subscription/data/quota_repository.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
```

At the top of `sendMessage()`, before any existing code, add the quota check block:

```dart
Future<void> sendMessage(String text) async {
  // ── Quota check ──────────────────────────────────────────────────────────
  final quotaState = ref.read(quotaProvider).valueOrNull;
  if (quotaState != null && quotaState.exhausted) {
    // UI (ChatPage) shows PaywallSheet. Notifier returns early.
    return;
  }
  final _isGrace = quotaState?.inGrace == true;

  // ── Existing chat logic (unchanged) ──────────────────────────────────────
  final userMsg = ChatMessage(role: MessageRole.user, content: text);
  // ... rest of the existing code unchanged ...
```

Then at the very end of `sendMessage()`, after setting `finalMessages` and `state = finalMessages;`, add the quota increment call:

```dart
  state = finalMessages;

  // ── Quota tracking ────────────────────────────────────────────────────────
  try {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      final repo = ref.read(quotaRepositoryProvider);
      if (_isGrace) {
        await repo.incrementGrace();
      } else {
        await repo.incrementMessage();
      }
    }
  } catch (_) {
    // Non-critical: quota write failure does not block chat.
  }
}
```

The full updated `sendMessage()` method with both additions:

```dart
Future<void> sendMessage(String text) async {
  // ── Quota check ──────────────────────────────────────────────────────────
  final quotaState = ref.read(quotaProvider).valueOrNull;
  if (quotaState != null && quotaState.exhausted) {
    return; // UI shows PaywallSheet; notifier bails out silently.
  }
  final _isGrace = quotaState?.inGrace == true;

  final userMsg = ChatMessage(role: MessageRole.user, content: text);
  state = [...state, userMsg];

  const placeholder = ChatMessage(
    role: MessageRole.assistant,
    content: '',
    isStreaming: true,
  );
  state = [...state, placeholder];

  final assistantIndex = state.length - 1;

  final baseMessages = state
      .where((m) => !m.isStreaming)
      .map((m) => m.toHermesMap())
      .toList();

  String? toneHint;
  try {
    toneHint = await ref.read(moodToneProvider.future);
  } catch (_) {}

  String? musicSuggestionHint;
  try {
    final moodPlaylist = await ref.read(moodPlaylistProvider.future);
    final isCalm = moodPlaylist?.moodCategory == MoodCategory.calm;
    final isPlaying =
        ref.read(musicPlayerNotifierProvider).currentTrack != null;
    if (isCalm && !isPlaying) {
      musicSuggestionHint =
          'If contextually appropriate, suggest the user play some music.';
    }
  } catch (_) {}

  final hermesMessages = [
    if (toneHint != null) {'role': 'system', 'content': toneHint},
    if (musicSuggestionHint != null)
      {'role': 'system', 'content': musicSuggestionHint},
    ...baseMessages,
  ];

  final config = await ref.read(assistantConfigProvider.future);
  final assistantName = config?.name ?? 'Rocky';

  final client = ref.read(hermesClientProvider);
  final aiModel = await ref
      .read(aiModelNotifierProvider.future)
      .catchError((_) => 'gemini_flash');
  final buffer = StringBuffer();
  var moodSaved = false;

  await for (final chunk in client.chatStream(
    messages: hermesMessages,
    assistantName: assistantName,
    aiModel: aiModel,
  )) {
    switch (chunk) {
      case TextChunk(:final text):
        buffer.write(text);
        final updated = List<ChatMessage>.from(state);
        updated[assistantIndex] = ChatMessage(
          role: MessageRole.assistant,
          content: buffer.toString(),
          isStreaming: true,
        );
        state = updated;
      case MoodChunk(:final score, :final label):
        if (!moodSaved) {
          moodSaved = true;
          unawaited(_saveMoodPassive(score, label));
        }
      case DoneChunk():
        break;
    }
  }

  final finalContent = buffer.toString();
  final eventMap = parseScheduledEvent(finalContent);

  Event? createdEvent;
  if (eventMap != null) {
    createdEvent = await _persistEvent(eventMap);
  }

  final finalMessages = List<ChatMessage>.from(state);
  finalMessages[assistantIndex] = ChatMessage(
    role: MessageRole.assistant,
    content: finalContent,
    isStreaming: false,
    scheduledEvent: createdEvent != null ? eventMap : null,
  );
  state = finalMessages;

  // ── Quota tracking ────────────────────────────────────────────────────────
  try {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      final repo = ref.read(quotaRepositoryProvider);
      if (_isGrace) {
        await repo.incrementGrace();
      } else {
        await repo.incrementMessage();
      }
    }
  } catch (_) {
    // Non-critical: quota write failure does not block chat.
  }
}
```

Also update the `catchError` fallback in the file from `'claude'` to `'gemini_flash'` (line already shown above).

- [ ] **Step 4: Run quota test to verify it passes**

```bash
cd /Users/upkarsingh/nivara
flutter test test/features/chat/chat_provider_quota_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Run full test suite**

```bash
cd /Users/upkarsingh/nivara
flutter test --reporter compact
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/chat/presentation/providers/chat_provider.dart \
        test/features/chat/chat_provider_quota_test.dart
git commit -m "feat(chat): integrate quota check and tracking into ChatNotifier.sendMessage"
```

---

## Task 13: Update `ChatPage` — banner, indicator, and paywall trigger

**Files:**
- Modify: `lib/features/chat/presentation/pages/chat_page.dart`

- [ ] **Step 1: Add imports to `chat_page.dart`**

Add these three imports at the top of `lib/features/chat/presentation/pages/chat_page.dart`:

```dart
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/paywall_sheet.dart';
import '../../../subscription/presentation/widgets/quota_banner.dart';
import '../../../subscription/presentation/widgets/quota_indicator.dart';
```

- [ ] **Step 2: Update the `onSend` callback to trigger paywall when exhausted**

Find the `ChatInputBar` section inside `build()`:

```dart
ChatInputBar(
  enabled: !isStreaming,
  onSend: (text) =>
      ref.read(chatNotifierProvider.notifier).sendMessage(text),
),
```

Replace it with:

```dart
ChatInputBar(
  enabled: !isStreaming,
  onSend: (text) {
    final quotaState = ref.read(quotaProvider).valueOrNull;
    if (quotaState?.exhausted == true) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const PaywallSheet(),
      );
      return;
    }
    ref.read(chatNotifierProvider.notifier).sendMessage(text);
  },
),
```

- [ ] **Step 3: Add `QuotaBanner` and `QuotaIndicator` to the column**

Find the `Column` in `build()`:

```dart
body: Column(
  children: [
    if (_showCheckIn) ...
    Expanded(child: ...),
    ChatInputBar(...),
    const SizedBox(height: 8),
  ],
),
```

Update it to:

```dart
body: Column(
  children: [
    // Grace message banner — shown when user is in 3-message grace window
    const QuotaBanner(),
    if (_showCheckIn)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: CheckInCard(
          onDismiss: () => setState(() => _showCheckIn = false),
        ),
      ),
    Expanded(
      child: messages.isEmpty
          ? Center(
              child: configAsync.when(
                data: (c) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _greeting(c),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) => MessageBubble(message: messages[i]),
            ),
    ),
    ChatInputBar(
      enabled: !isStreaming,
      onSend: (text) {
        final quotaState = ref.read(quotaProvider).valueOrNull;
        if (quotaState?.exhausted == true) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const PaywallSheet(),
          );
          return;
        }
        ref.read(chatNotifierProvider.notifier).sendMessage(text);
      },
    ),
    // Message counter for Free tier only
    const QuotaIndicator(),
    const SizedBox(height: 8),
  ],
),
```

- [ ] **Step 4: Verify it compiles**

```bash
cd /Users/upkarsingh/nivara
flutter analyze lib/features/chat/presentation/pages/chat_page.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Run full tests**

```bash
cd /Users/upkarsingh/nivara
flutter test --reporter compact
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/chat/presentation/pages/chat_page.dart
git commit -m "feat(chat): add QuotaBanner, QuotaIndicator, and paywall trigger to ChatPage"
```

---

## Task 14: Real `RevenueCatServiceImpl` + `main.dart` init

**Files:**
- Modify: `lib/features/subscription/data/revenue_cat_service.dart`
- Modify: `lib/main.dart`

> **Pre-requisite:** RevenueCat products and entitlements must be set up in App Store Connect, Google Play Console, and the RevenueCat dashboard. See the spec (`docs/superpowers/specs/2026-05-16-subscription-paywall-design.md`, RevenueCat Setup section). Store the API keys in Dart build environment variables: `--dart-define=REVENUECAT_IOS_KEY=...` and `--dart-define=REVENUECAT_ANDROID_KEY=...`.

- [ ] **Step 1: Add `RevenueCatServiceImpl` to `revenue_cat_service.dart`**

Append the following class to the end of `lib/features/subscription/data/revenue_cat_service.dart`:

```dart
// Import at top of file (add alongside existing imports):
// import 'dart:io' show Platform;
// import 'package:purchases_flutter/purchases_flutter.dart';

import 'dart:io' show Platform;
import 'package:purchases_flutter/purchases_flutter.dart';

/// Production implementation backed by the RevenueCat SDK.
class RevenueCatServiceImpl implements RevenueCatService {
  static const _iosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const _androidKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  @override
  Future<void> init(String apiKey) async {
    await Purchases.setLogLevel(LogLevel.warning);
    final config = PurchasesConfiguration(apiKey);
    await Purchases.configure(config);
  }

  Future<void> initForPlatform() async {
    final key = Platform.isIOS ? _iosKey : _androidKey;
    await init(key);
  }

  @override
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.containsKey('premium')) {
        return SubscriptionTier.premium;
      }
      if (info.entitlements.active.containsKey('pro')) {
        return SubscriptionTier.pro;
      }
      return SubscriptionTier.free;
    } catch (_) {
      return SubscriptionTier.free; // safe fallback
    }
  }

  @override
  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
```

> **Note:** Add the two `dart:io` and `purchases_flutter` imports at the **top** of the file, not inside the class body.

- [ ] **Step 2: Update `main.dart` to init RevenueCat before `runApp`**

In `lib/main.dart`, add the import:

```dart
import 'features/subscription/data/revenue_cat_service.dart';
```

Inside `main()`, after the `MoodNotificationService` block and before `runApp(...)`, add:

```dart
  // Initialize RevenueCat
  final rcService = RevenueCatServiceImpl();
  try {
    await rcService.initForPlatform();
  } on Exception catch (e) {
    debugPrint('RevenueCat init failed: $e');
    // App continues — defaults to Free tier via RevenueCatServiceStub fallback
  }
```

And update `ProviderScope` to override `revenueCatServiceProvider` with the real implementation:

```dart
  runApp(
    ProviderScope(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(rcService),
      ],
      child: const NivaraApp(),
    ),
  );
```

The complete updated `main()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await MoodNotificationService.init();
    final granted = await MoodNotificationService.requestPermissions();
    if (granted) {
      await MoodNotificationService.scheduleDailyReminder();
    }
  } on Exception catch (e) {
    debugPrint('Notification setup failed: $e');
  }

  // Initialize RevenueCat (degrades gracefully to Free tier on failure).
  RevenueCatService rcService = RevenueCatServiceStub();
  try {
    final impl = RevenueCatServiceImpl();
    await impl.initForPlatform();
    rcService = impl;
  } on Exception catch (e) {
    debugPrint('RevenueCat init failed, using stub: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(rcService),
      ],
      child: const NivaraApp(),
    ),
  );
}
```

- [ ] **Step 3: Verify it compiles**

```bash
cd /Users/upkarsingh/nivara
flutter analyze lib/main.dart lib/features/subscription/data/revenue_cat_service.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Run full tests**

```bash
cd /Users/upkarsingh/nivara
flutter test --reporter compact
```

Expected: all pass (tests use stub).

- [ ] **Step 5: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/subscription/data/revenue_cat_service.dart lib/main.dart
git commit -m "feat(subscription): add RevenueCatServiceImpl and init in main.dart"
```

---

## Task 15: Feature gating — music, ElevenLabs, wake word

**Files:**
- Modify: `lib/features/music/presentation/pages/music_page.dart`
- Modify: `lib/voice/voice_settings_page.dart`
- Modify: `lib/voice/voice_provider.dart`

### 15a — Music page gating

- [ ] **Step 1: Add tier check to `music_page.dart`**

Add these imports to the top of `lib/features/music/presentation/pages/music_page.dart`:

```dart
import 'package:nivara/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:nivara/features/subscription/presentation/widgets/paywall_sheet.dart';
```

Inside `MusicPage.build()`, right after `final state = ref.watch(musicPlayerNotifierProvider);`, add:

```dart
    final tierConfig = ref.watch(tierConfigProvider);

    if (!tierConfig.musicEnabled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Music'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off_outlined, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              const Text(
                'Music is a Pro feature',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upgrade to listen to mood-matched playlists.',
                style: TextStyle(color: Colors.white38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const PaywallSheet(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                ),
                child: const Text('See plans'),
              ),
            ],
          ),
        ),
      );
    }
```

Place this block right before the existing `return Scaffold(...)` of the full music player.

### 15b — ElevenLabs gating in `voice_settings_page.dart`

- [ ] **Step 2: Add tier check to the ElevenLabs section**

Add these imports to `lib/voice/voice_settings_page.dart`:

```dart
import '../features/subscription/presentation/providers/subscription_provider.dart';
import '../features/subscription/presentation/widgets/paywall_sheet.dart';
```

Find the ElevenLabs `RadioListTile` section in the `_VoiceSettingsPageState.build()` method. It currently renders the ElevenLabs option unconditionally. Wrap it in a tier check.

Locate the `TtsProvider.elevenLabs` radio tile and wrap it so that if `!tierConfig.elevenLabsEnabled`, it renders a locked tile instead:

```dart
// Inside the settings data widget, add at the top of the data builder:
final tierConfig = ref.watch(tierConfigProvider);

// Then for the ElevenLabs tile, replace:
RadioListTile<TtsProvider>(
  value: TtsProvider.elevenLabs,
  // ...existing props...
)

// With:
if (tierConfig.elevenLabsEnabled)
  RadioListTile<TtsProvider>(
    value: TtsProvider.elevenLabs,
    // ...existing props unchanged...
  )
else
  ListTile(
    leading: const Icon(Icons.lock_outline, color: Colors.white38),
    title: const Text('ElevenLabs TTS',
        style: TextStyle(color: Colors.white38)),
    subtitle: const Text('Premium feature',
        style: TextStyle(color: Colors.white30, fontSize: 12)),
    onTap: () => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PaywallSheet(),
    ),
  ),
```

### 15c — Wake word quota in `voice_provider.dart`

- [ ] **Step 3: Add wake word quota check to `_onWakeWordDetected`**

Add these imports to `lib/voice/voice_provider.dart`:

```dart
import '../features/subscription/data/wake_word_quota_repository.dart';
import '../features/subscription/presentation/providers/subscription_provider.dart';
```

Replace `void _onWakeWordDetected()` with the async version:

```dart
Future<void> _onWakeWordDetected() async {
  if (state != VoiceState.idle) return;

  // Check wake word quota
  try {
    final tierConfig = ref.read(tierConfigProvider);
    final limit = tierConfig.wakeWordLimit;
    if (limit != null) {
      final wakeRepo = ref.read(wakeWordQuotaRepositoryProvider);
      final usage = await wakeRepo.get();

      // For Free tier (wakeWordLimitIsMonthly == false), check lifetime total.
      // For Pro tier (wakeWordLimitIsMonthly == true), check monthly total.
      final activationsUsed = tierConfig.wakeWordLimitIsMonthly && usage.isNewPeriod
          ? 0
          : usage.activationsUsed;

      if (activationsUsed >= limit) {
        // Quota exhausted — silently ignore wake word activation.
        return;
      }
      // Increment usage (non-blocking).
      unawaited(wakeRepo.increment());
    }
  } catch (_) {
    // Non-critical — degrade gracefully, allow activation.
  }

  state = VoiceState.listening;
  _startListening();
}
```

Also update the `_wakeWord!.onWakeWord` assignment to use the async version:

```dart
_wakeWord!.onWakeWord = () => unawaited(_onWakeWordDetected());
```

- [ ] **Step 4: Verify all three files compile**

```bash
cd /Users/upkarsingh/nivara
flutter analyze lib/features/music/presentation/pages/music_page.dart \
              lib/voice/voice_settings_page.dart \
              lib/voice/voice_provider.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Run full test suite**

```bash
cd /Users/upkarsingh/nivara
flutter test --reporter compact
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/upkarsingh/nivara
git add lib/features/music/presentation/pages/music_page.dart \
        lib/voice/voice_settings_page.dart \
        lib/voice/voice_provider.dart
git commit -m "feat(subscription): gate music, ElevenLabs, and wake word by tier"
```

---

## Final verification

- [ ] **Run the full test suite one last time**

```bash
cd /Users/upkarsingh/nivara
flutter test --reporter compact
```

Expected: all tests pass, zero failures.

- [ ] **Analyze the entire project**

```bash
cd /Users/upkarsingh/nivara
flutter analyze
```

Expected: `No issues found!`
