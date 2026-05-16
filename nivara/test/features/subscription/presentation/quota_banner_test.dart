import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:nivara/features/subscription/presentation/widgets/quota_banner.dart';
import 'package:nivara/features/subscription/presentation/widgets/quota_indicator.dart';

// Helpers to build a QuotaState for testing.
QuotaState _makeState({
  bool inGrace = false,
  bool exhausted = false,
  int graceUsed = 0,
  int used = 0,
  int quota = 3000,
}) {
  return QuotaState(
    messagesUsed: used,
    monthlyQuota: quota,
    remaining: quota - used,
    graceUsed: graceUsed,
    inGrace: inGrace,
    exhausted: exhausted,
    graceRemaining: 3 - graceUsed,
  );
}

Widget _wrap(Widget child, {AsyncValue<QuotaState>? quotaOverride}) {
  return ProviderScope(
    overrides: [
      if (quotaOverride != null)
        quotaProvider.overrideWith((_) => Stream.value(quotaOverride.value!)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('QuotaBanner', () {
    testWidgets('shows banner when inGrace=true', (tester) async {
      final state = _makeState(inGrace: true, graceUsed: 1, used: 3000);
      await tester.pumpWidget(_wrap(
        QuotaBanner(quotaState: state),
      ));
      await tester.pump();

      expect(find.textContaining('grace'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Upgrade'), findsOneWidget);
    });

    testWidgets('hidden when not inGrace', (tester) async {
      final state = _makeState(inGrace: false, used: 100);
      await tester.pumpWidget(_wrap(
        QuotaBanner(quotaState: state),
      ));
      await tester.pump();

      expect(find.byType(QuotaBanner), findsOneWidget);
      // Banner container should be empty (SizedBox.shrink)
      expect(find.textContaining('grace'), findsNothing);
    });
  });

  group('QuotaIndicator', () {
    testWidgets('shows message count on Free tier', (tester) async {
      final state = _makeState(used: 1842, quota: 3000);
      await tester.pumpWidget(_wrap(
        QuotaIndicator(quotaState: state, isFree: true),
      ));
      await tester.pump();

      expect(find.textContaining('1,842'), findsOneWidget);
      expect(find.textContaining('3,000'), findsOneWidget);
    });

    testWidgets('hidden on non-Free tier', (tester) async {
      final state = _makeState(used: 5000, quota: 20000);
      await tester.pumpWidget(_wrap(
        QuotaIndicator(quotaState: state, isFree: false),
      ));
      await tester.pump();

      expect(find.textContaining('5,000'), findsNothing);
    });
  });
}
