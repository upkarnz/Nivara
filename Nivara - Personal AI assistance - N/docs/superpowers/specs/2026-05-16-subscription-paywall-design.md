# Subscription + Paywall Design

## Goal

Add RevenueCat-powered Free / Pro / Premium subscription tiers to Nivara, with dynamic message quotas driven by each tier's monthly AI budget and the user's chosen model. Introverts who want to chat heavily use Gemini Flash (default on all tiers) for an effectively unlimited feel; users who need deeper research can switch to higher-quality models at the cost of a lower quota.

## Architecture

**RevenueCat** manages entitlements and purchase flow. Message quota is tracked in Firestore. All quota checks are client-side — fraud risk is low for a personal AI app and this avoids adding latency to every message.

**Tech Stack**
- `purchases_flutter` — RevenueCat SDK
- Firestore — quota persistence (`users/{uid}/quota`)
- Riverpod — `subscriptionProvider`, `quotaProvider`
- Flutter — `PaywallSheet`, `QuotaBanner`, `QuotaIndicator`, updated `ModelSelectorWidget`

---

## Tier Config

### Free
- **Default model:** Gemini 2.0 Flash
- **Monthly AI budget:** $0.15
- **Dynamic quota:** ~3,000 msgs/month (~100/day)
- **History:** 7 days
- **Music:** disabled
- **Wake word:** 5 activations total (trial only)
- **ElevenLabs TTS:** disabled
- **Model override:** not allowed (Gemini Flash only)
- **Price:** Free

### Pro
- **Default model:** Gemini 2.0 Flash
- **Monthly AI budget:** $1.00
- **Dynamic quota on default model:** ~20,000 msgs/month (unlimited feel)
- **History:** unlimited
- **Music:** enabled
- **Wake word:** 30 activations/month
- **ElevenLabs TTS:** disabled
- **Model override:** allowed (GPT-4o Mini, Claude Haiku)
- **Price:** $7.99/month or $59.99/year

### Premium
- **Default model:** Gemini 2.0 Flash
- **Monthly AI budget:** $9.00
- **Dynamic quota on default model:** ~180,000 msgs/month (unlimited)
- **History:** unlimited
- **Music:** enabled
- **Wake word:** unlimited
- **ElevenLabs TTS:** enabled
- **Model override:** allowed (all models)
- **Price:** $19.99/month or $149.99/year

---

## Model Cost Reference (per message, ~800 tokens avg)

| Model | Cost/msg | Pro quota | Premium quota |
|-------|----------|-----------|---------------|
| Gemini 2.0 Flash | $0.00005 | ~20,000 | ~180,000 |
| GPT-4o Mini | $0.00012 | ~8,300 | ~75,000 |
| Claude Haiku 3.5 | $0.0006 | ~1,600 | ~15,000 |
| Claude Sonnet | $0.006 | — | ~1,500 |
| GPT-4o | $0.005 | — | ~1,800 |

`ModelBudget.messagesPerMonth(tier, model)` = `tier.monthlyBudgetUsd / model.costPerMessage`

---

## Domain Layer

### `SubscriptionTier` enum
```dart
enum SubscriptionTier { free, pro, premium }
```

### `TierConfig`
Immutable value object holding all limits for a tier. Static factory `TierConfig.forTier(SubscriptionTier)` returns the correct config. Fields:
- `monthlyBudgetUsd` (double)
- `defaultModel` (String)
- `historyDays` (int — `null` = unlimited)
- `musicEnabled` (bool)
- `wakeWordLimit` (int — `null` = unlimited)
- `elevenLabsEnabled` (bool)
- `modelOverrideAllowed` (bool)
- `availableModels` (List<String>)

### `ModelBudget`
Pure utility class. `messagesPerMonth(double budgetUsd, String model)` → int. `costPerMessage(String model)` → double. Used by `quotaProvider` and Settings UI.

---

## Data Layer

### `RevenueCatService`
Wraps `purchases_flutter`. Initialised in `main()` before `runApp`. Methods:
- `init(String apiKey)` — called once at startup
- `getCurrentTier()` → `Future<SubscriptionTier>` — reads active entitlement (`free`/`pro`/`premium`)
- `purchasePackage(Package pkg)` → `Future<void>`
- `restorePurchases()` → `Future<void>`
- `getOfferings()` → `Future<Offerings>` — for paywall package list

RevenueCat entitlement identifiers:
- `pro` — Pro tier
- `premium` — Premium tier
- (no entitlement = Free)

### `QuotaRepository`
Reads and writes `users/{uid}/quota` in Firestore:
```
{
  messagesUsed: int,
  graceUsed: int,       // 0–3
  periodStart: String,  // ISO8601 date of current billing period start
  model: String,        // currently active model override (or tier default)
}
```
- `getQuota(String uid)` → `Stream<QuotaDoc>`
- `incrementMessage(String uid)` → `Future<void>` — increments `messagesUsed`
- `incrementGrace(String uid)` → `Future<void>` — increments `graceUsed`
- `resetIfNewPeriod(String uid)` → resets `messagesUsed` and `graceUsed` to 0, updates `periodStart` if >30 days elapsed
- `setModel(String uid, String model)` → `Future<void>`

---

## Providers

### `subscriptionProvider`
```dart
final subscriptionProvider = FutureProvider<SubscriptionTier>((ref) async {
  return ref.read(revenueCatServiceProvider).getCurrentTier();
});
```
Invalidated after purchase or restore.

### `quotaProvider`
`StreamProvider<QuotaState>` combining:
- `subscriptionProvider` → tier
- `QuotaRepository` stream → raw Firestore doc
- User's selected model from `aiModelNotifierProvider`

Exposes `QuotaState`:
```dart
class QuotaState {
  final int messagesUsed;
  final int monthlyQuota;   // computed from tier budget + model
  final int remaining;      // monthlyQuota - messagesUsed
  final int graceUsed;      // 0–3
  final bool inGrace;       // remaining <= 0 && graceUsed < 3
  final bool exhausted;     // remaining <= 0 && graceUsed >= 3
  final int graceRemaining; // 3 - graceUsed
}
```

### `tierConfigProvider`
```dart
final tierConfigProvider = Provider<TierConfig>((ref) {
  final tier = ref.watch(subscriptionProvider).valueOrNull ?? SubscriptionTier.free;
  return TierConfig.forTier(tier);
});
```

---

## Chat Integration

`ChatNotifier.sendMessage()` checks quota before sending:

```
1. Read quotaProvider state
2. If exhausted → show PaywallSheet, return early
3. If inGrace → increment graceUsed, show QuotaBanner, proceed
4. If ok → proceed normally
5. On successful AI response → increment messagesUsed
```

Grace messages show a persistent amber banner in `ChatPage` until user upgrades or the period resets.

---

## UI Components

### `PaywallSheet`
Full bottom sheet with three tier cards. Triggered when `exhausted`.
- Shows tier name, price, feature bullet list
- CTA button per tier: "Upgrade to Pro" / "Upgrade to Premium"
- "Restore Purchases" text link at bottom
- Dismissible (Free users can close and use grace messages; once exhausted, sheet re-appears on next send)
- On purchase success: invalidate `subscriptionProvider`, dismiss sheet

### `QuotaBanner`
Slim amber banner inside `ChatPage`, shown only when `inGrace`:
```
"You've used all your messages. X grace messages remaining.  [Upgrade →]"
```
Hidden on Pro/Premium.

### `QuotaIndicator`
Subtle text below chat input, shown on Free tier only:
```
"1,842 / 3,000 messages this month"
```
Turns red when `remaining < 50`.

### `ModelSelectorWidget` (updated)
Existing widget gains:
- Dynamic quota label per model row (computed via `ModelBudget`)
- Lock icon on models not available for current tier
- Callout text at top:
  > "Gemini Flash gives you the most messages. Switch to another model when you need deeper research or higher quality responses."

**Free tier** — all rows locked except Gemini Flash with upgrade prompt.

**Pro tier:**
```
● Gemini Flash    ~20,000 msgs/month   ✓ default
○ GPT-4o Mini    ~8,300 msgs/month    better for research
○ Claude Haiku   ~1,600 msgs/month    best writing quality
```

**Premium tier:**
```
● Gemini Flash    ~180,000 msgs/month  ✓ default
○ GPT-4o Mini    ~75,000 msgs/month   better for research
○ Claude Haiku   ~15,000 msgs/month   best writing quality
○ Claude Sonnet  ~1,500 msgs/month    deepest reasoning
○ GPT-4o         ~1,800 msgs/month    deepest reasoning
```

---

## Feature Gating

Features gated by `tierConfigProvider` throughout the app:

| Feature | Free | Pro | Premium |
|---------|------|-----|---------|
| Chat | ✓ (quota) | ✓ (unlimited) | ✓ (unlimited) |
| Chat history | 7 days | unlimited | unlimited |
| Music playback | ✗ | ✓ | ✓ |
| Wake word | 5 total | 30/month | unlimited |
| ElevenLabs TTS | ✗ | ✗ | ✓ |
| Model override | ✗ | ✓ (2 models) | ✓ (all models) |
| Grace messages | 3 | — | — |

Gating points:
- `MusicPage` / `MiniPlayerWidget` → check `tierConfig.musicEnabled`, show upgrade prompt if false
- `VoiceNotifier._onWakeWordDetected()` → check `wakeWordLimit`, track activations in Firestore
- `VoiceSettingsPage` ElevenLabs section → locked with upgrade prompt if `!elevenLabsEnabled`
- `ModelSelectorWidget` → model rows locked per `availableModels`

---

## Firestore Schema Addition

```
users/{uid}/quota
  messagesUsed: number
  graceUsed: number
  periodStart: string (ISO8601)
  model: string

users/{uid}/wakeWordUsage
  activationsUsed: number
  periodStart: string
```

Wake word activations tracked separately in `WakeWordQuotaRepository` — same pattern as `QuotaRepository`.

---

## RevenueCat Setup

1. Create products in App Store Connect and Google Play Console:
   - `nivara_pro_monthly` — $7.99/month
   - `nivara_pro_annual` — $59.99/year
   - `nivara_premium_monthly` — $19.99/month
   - `nivara_premium_annual` — $149.99/year

2. Create entitlements in RevenueCat dashboard:
   - `pro` → maps to pro products
   - `premium` → maps to premium products

3. RevenueCat API keys stored in:
   - iOS: `REVENUECAT_IOS_KEY` (env / build config)
   - Android: `REVENUECAT_ANDROID_KEY`

---

## Error Handling

- RevenueCat purchase cancelled → silent (user dismissed)
- RevenueCat network error → show snackbar "Purchase failed, please try again"
- Firestore quota write failure → degrade gracefully (don't block message), retry next send
- `subscriptionProvider` error → default to `SubscriptionTier.free` (safe fallback)

---

## Testing

- Unit: `TierConfig.forTier()`, `ModelBudget.messagesPerMonth()`, `QuotaState` logic
- Unit: `QuotaRepository` with Firestore emulator
- Widget: `PaywallSheet` renders correct tier cards, purchase CTA fires
- Widget: `QuotaBanner` shown/hidden per `QuotaState`
- Widget: `ModelSelectorWidget` locks correct rows per tier
- Integration: `ChatNotifier.sendMessage()` blocks when `exhausted`, decrements quota correctly
- No RevenueCat SDK calls in tests — `RevenueCatService` behind an abstract interface, stubbed in tests
