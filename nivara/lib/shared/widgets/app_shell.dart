import 'package:flutter/material.dart';
import 'package:nivara/features/music/presentation/widgets/mini_player_widget.dart';

/// Persistent shell wrapping all main authenticated routes.
/// Renders [child] as the main body and keeps [MiniPlayerWidget]
/// pinned at the bottom of every screen in the shell.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const MiniPlayerWidget(),
    );
  }
}
