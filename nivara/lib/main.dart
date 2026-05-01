import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

void main() {
  runApp(const ProviderScope(child: NivaraApp()));
}

class NivaraApp extends StatelessWidget {
  const NivaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nivara',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const Scaffold(
        body: Center(
          child: Text('Nivara', style: TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
