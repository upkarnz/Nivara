import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/data/revenue_cat_service.dart';
import 'package:nivara/features/subscription/presentation/widgets/paywall_sheet.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      revenueCatServiceProvider.overrideWithValue(RevenueCatServiceStub()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('PaywallSheet renders Pro and Premium tier cards', (tester) async {
    await tester.pumpWidget(_wrap(const PaywallSheet()));
    await tester.pump();

    expect(find.text('Pro'), findsAtLeastNWidgets(1));
    expect(find.text('Premium'), findsAtLeastNWidgets(1));
  });

  testWidgets('PaywallSheet shows upgrade CTA buttons', (tester) async {
    await tester.pumpWidget(_wrap(const PaywallSheet()));
    await tester.pump();

    expect(find.textContaining('Upgrade to Pro'), findsOneWidget);
    expect(find.textContaining('Upgrade to Premium'), findsOneWidget);
  });

  testWidgets('PaywallSheet shows Restore Purchases link', (tester) async {
    await tester.pumpWidget(_wrap(const PaywallSheet()));
    await tester.pump();

    expect(find.text('Restore Purchases'), findsOneWidget);
  });
}
