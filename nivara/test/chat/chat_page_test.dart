import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nivara/features/chat/presentation/pages/chat_page.dart';

void main() {
  testWidgets('chat page renders message input bar', (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const ChatPage())],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });
}
