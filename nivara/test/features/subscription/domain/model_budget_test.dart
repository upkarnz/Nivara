import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/domain/model_budget.dart';

void main() {
  group('ModelBudget.costPerMessage', () {
    test('gemini_flash costs 0.00005', () {
      expect(ModelBudget.costPerMessage('gemini_flash'), 0.00005);
    });

    test('gpt4o_mini costs 0.00012', () {
      expect(ModelBudget.costPerMessage('gpt4o_mini'), 0.00012);
    });

    test('claude_haiku costs 0.0006', () {
      expect(ModelBudget.costPerMessage('claude_haiku'), 0.0006);
    });

    test('claude_sonnet costs 0.006', () {
      expect(ModelBudget.costPerMessage('claude_sonnet'), 0.006);
    });

    test('gpt4o costs 0.005', () {
      expect(ModelBudget.costPerMessage('gpt4o'), 0.005);
    });

    test('unknown model falls back to gemini_flash cost', () {
      expect(ModelBudget.costPerMessage('unknown_model'), 0.00005);
    });
  });

  group('ModelBudget.messagesPerMonth', () {
    test('Free + gemini_flash yields ~3000 messages', () {
      final quota = ModelBudget.messagesPerMonth(budgetUsd: 0.15, model: 'gemini_flash');
      expect(quota, 3000);
    });

    test('Pro + gemini_flash yields ~20000 messages', () {
      final quota = ModelBudget.messagesPerMonth(budgetUsd: 1.00, model: 'gemini_flash');
      expect(quota, 20000);
    });

    test('Pro + claude_haiku yields ~1666 messages', () {
      final quota = ModelBudget.messagesPerMonth(budgetUsd: 1.00, model: 'claude_haiku');
      expect(quota, 1666);
    });

    test('Premium + gemini_flash yields ~180000 messages', () {
      final quota = ModelBudget.messagesPerMonth(budgetUsd: 9.00, model: 'gemini_flash');
      expect(quota, 180000);
    });

    test('result is always at least 1', () {
      final quota = ModelBudget.messagesPerMonth(budgetUsd: 0.000001, model: 'claude_sonnet');
      expect(quota, greaterThanOrEqualTo(1));
    });

    test('result is capped at 999999', () {
      final quota = ModelBudget.messagesPerMonth(budgetUsd: 999999.0, model: 'gemini_flash');
      expect(quota, 999999);
    });
  });
}
