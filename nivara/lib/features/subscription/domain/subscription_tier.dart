/// Subscription tiers available in Nivara.
enum SubscriptionTier { free, pro, premium }

/// Immutable value object holding all limits for a subscription tier.
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

  /// Monthly AI spend budget in USD used to compute dynamic message quotas.
  final double monthlyBudgetUsd;

  /// The default model ID for this tier (e.g. 'gemini_flash').
  final String defaultModel;

  /// Maximum chat history retention in days; null means unlimited.
  final int? historyDays;

  /// Whether background music playback is available.
  final bool musicEnabled;

  /// Maximum wake word activations allowed; null means unlimited.
  final int? wakeWordLimit;

  /// true = wakeWordLimit resets monthly; false = lifetime total (Free).
  final bool wakeWordLimitIsMonthly;

  /// Whether ElevenLabs TTS voices are unlocked.
  final bool elevenLabsEnabled;

  /// Whether the user may switch to a non-default AI model.
  final bool modelOverrideAllowed;

  /// List of model IDs the user may select.
  final List<String> availableModels;

  /// Returns the [TierConfig] for the given [tier].
  static TierConfig forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return const TierConfig(
          monthlyBudgetUsd: 0.15,
          defaultModel: 'groq',
          historyDays: 7,
          musicEnabled: false,
          wakeWordLimit: 5,
          wakeWordLimitIsMonthly: false,
          elevenLabsEnabled: false,
          modelOverrideAllowed: true,
          availableModels: ['groq'],
        );
      case SubscriptionTier.pro:
        return const TierConfig(
          monthlyBudgetUsd: 1.00,
          defaultModel: 'groq',
          historyDays: null,
          musicEnabled: true,
          wakeWordLimit: 30,
          wakeWordLimitIsMonthly: true,
          elevenLabsEnabled: false,
          modelOverrideAllowed: true,
          availableModels: ['groq', 'gpt4o_mini', 'claude_haiku'],
        );
      case SubscriptionTier.premium:
        return const TierConfig(
          monthlyBudgetUsd: 9.00,
          defaultModel: 'groq',
          historyDays: null,
          musicEnabled: true,
          wakeWordLimit: null,
          wakeWordLimitIsMonthly: true,
          elevenLabsEnabled: true,
          modelOverrideAllowed: true,
          availableModels: ['groq', 'gpt4o_mini', 'claude_haiku', 'claude_sonnet', 'gpt4o'],
        );
    }
  }
}
