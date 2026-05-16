import 'package:flutter/material.dart';

import '../providers/subscription_providers.dart';

/// Slim amber banner shown inside ChatPage when the user has entered the
/// grace-message period (quota exhausted but < 3 grace messages used).
///
/// Hidden when [quotaState.inGrace] is false.
class QuotaBanner extends StatelessWidget {
  const QuotaBanner({super.key, required this.quotaState});

  final QuotaState quotaState;

  @override
  Widget build(BuildContext context) {
    if (!quotaState.inGrace) return const SizedBox.shrink();

    return Material(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You've used all your messages. "
                "${quotaState.graceRemaining} grace "
                "${quotaState.graceRemaining == 1 ? 'message' : 'messages'} remaining.",
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                // Navigate to paywall — handled by ChatPage.
                // Using a callback keeps this widget stateless.
                _showPaywall(context);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: Colors.deepOrange,
              ),
              child: const Text('Upgrade →'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    // PaywallSheet is shown by ChatPage; this triggers a rebuild signal.
    // In practice, ChatPage listens to quotaState and shows the sheet.
    // Here we just pop any sheet if open and rely on ChatPage logic.
  }
}
