import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nivara/features/auth/presentation/pages/sign_in_page.dart';

void main() {
  testWidgets('sign in page shows Google and Email buttons', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SignInPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign in with Email'), findsOneWidget);
  });
}
