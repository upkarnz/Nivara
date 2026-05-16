/// Pure utility for computing per-message AI costs and monthly message quotas.
class ModelBudget {
  ModelBudget._();

  /// Cost per message (~800 tokens avg) for each supported model ID.
  static const _costs = <String, double>{
    'gemini_flash': 0.00005,
    'gpt4o_mini': 0.00012,
    'claude_haiku': 0.0006,
    'claude_sonnet': 0.006,
    'gpt4o': 0.005,
  };

  /// Returns cost per message for [model], falling back to gemini_flash if unknown.
  static double costPerMessage(String model) =>
      _costs[model] ?? _costs['gemini_flash']!;

  /// Returns the number of messages per month a user can send given [budgetUsd]
  /// and [model]. Result is clamped to [1, 999999].
  static int messagesPerMonth({
    required double budgetUsd,
    required String model,
  }) {
    final cost = costPerMessage(model);
    // Use integer arithmetic (scaled by 1e7) to avoid IEEE-754 rounding errors.
    final budgetMicro = (budgetUsd * 1e7).round();
    final costMicro = (cost * 1e7).round();
    return (budgetMicro ~/ costMicro).clamp(1, 999999);
  }
}
