import 'package:flutter/material.dart';

import '../providers/subscription_providers.dart';

/// Subtle message counter shown below the chat input on the Free tier only.
///
/// Turns red when [quotaState.remaining] < 50.
/// Hidden entirely on Pro/Premium ([isFree] = false).
class QuotaIndicator extends StatelessWidget {
  const QuotaIndicator({
    super.key,
    required this.quotaState,
    required this.isFree,
  });

  final QuotaState quotaState;
  final bool isFree;

  /// Formats [n] with thousands separators (e.g. 1842 → "1,842").
  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!isFree) return const SizedBox.shrink();

    final isLow = quotaState.remaining < 50;
    final color = isLow
        ? Colors.red
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '${_fmt(quotaState.messagesUsed)} / '
        '${_fmt(quotaState.monthlyQuota)} messages this month',
        style: TextStyle(fontSize: 12, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}
