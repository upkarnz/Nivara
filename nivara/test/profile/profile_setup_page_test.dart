import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nivara/features/profile/presentation/pages/profile_setup_page.dart';

void main() {
  testWidgets('profile setup page renders name and language fields',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ProfileSetupPage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    expect(find.text('Your Name *'), findsOneWidget);
    expect(find.text('Preferred Language'), findsOneWidget);
    // Voice preference section
    expect(find.text('Assistant Voice'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Neutral'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
  });
}
