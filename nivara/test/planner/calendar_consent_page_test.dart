import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/planner/presentation/pages/calendar_consent_page.dart';

Widget _wrap({VoidCallback? onAllow, VoidCallback? onSkip}) => MaterialApp(
      home: CalendarConsentPage(
        onAllow: onAllow ?? () {},
        onSkip: onSkip ?? () {},
      ),
    );

void main() {
  testWidgets('shows connect title', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Connect Google Calendar'), findsOneWidget);
  });

  testWidgets('shows allow and skip buttons', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('tapping Allow calls onAllow', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(onAllow: () => called = true));
    await tester.tap(find.text('Allow'));
    expect(called, isTrue);
  });

  testWidgets('tapping Skip calls onSkip', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(onSkip: () => called = true));
    await tester.tap(find.text('Skip'));
    expect(called, isTrue);
  });
}
