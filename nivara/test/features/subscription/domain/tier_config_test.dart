import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/domain/subscription_tier.dart';

void main() {
  group('TierConfig.forTier', () {
    test('Free tier has correct budget and defaults', () {
      final config = TierConfig.forTier(SubscriptionTier.free);
      expect(config.monthlyBudgetUsd, 0.15);
      expect(config.defaultModel, 'gemini_flash');
      expect(config.historyDays, 7);
      expect(config.musicEnabled, isFalse);
      expect(config.wakeWordLimit, 5);
      expect(config.wakeWordLimitIsMonthly, isFalse);
      expect(config.elevenLabsEnabled, isFalse);
      expect(config.modelOverrideAllowed, isFalse);
      expect(config.availableModels, ['gemini_flash']);
    });

    test('Pro tier has correct budget and features', () {
      final config = TierConfig.forTier(SubscriptionTier.pro);
      expect(config.monthlyBudgetUsd, 1.00);
      expect(config.defaultModel, 'gemini_flash');
      expect(config.historyDays, isNull);
      expect(config.musicEnabled, isTrue);
      expect(config.wakeWordLimit, 30);
      expect(config.wakeWordLimitIsMonthly, isTrue);
      expect(config.elevenLabsEnabled, isFalse);
      expect(config.modelOverrideAllowed, isTrue);
      expect(config.availableModels, containsAll(['gemini_flash', 'gpt4o_mini', 'claude_haiku']));
      expect(config.availableModels, isNot(contains('claude_sonnet')));
      expect(config.availableModels, isNot(contains('gpt4o')));
    });

    test('Premium tier has correct budget and all features', () {
      final config = TierConfig.forTier(SubscriptionTier.premium);
      expect(config.monthlyBudgetUsd, 9.00);
      expect(config.defaultModel, 'gemini_flash');
      expect(config.historyDays, isNull);
      expect(config.musicEnabled, isTrue);
      expect(config.wakeWordLimit, isNull);
      expect(config.wakeWordLimitIsMonthly, isTrue);
      expect(config.elevenLabsEnabled, isTrue);
      expect(config.modelOverrideAllowed, isTrue);
      expect(config.availableModels,
          containsAll(['gemini_flash', 'gpt4o_mini', 'claude_haiku', 'claude_sonnet', 'gpt4o']));
    });
  });

  group('SubscriptionTier enum', () {
    test('has three values', () {
      expect(SubscriptionTier.values.length, 3);
    });

    test('values are free, pro, premium', () {
      expect(SubscriptionTier.values, [
        SubscriptionTier.free,
        SubscriptionTier.pro,
        SubscriptionTier.premium,
      ]);
    });
  });
}
