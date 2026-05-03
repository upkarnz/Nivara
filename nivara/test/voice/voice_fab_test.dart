import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/voice/voice_fab.dart';
import 'package:nivara/voice/voice_provider.dart';
import 'package:nivara/voice/voice_state.dart';

// Helper to build the FAB under a ProviderScope that overrides voiceProvider.
Widget _buildFab(VoiceState overrideState) => ProviderScope(
      overrides: [
        voiceProvider.overrideWith(() => _FakeVoiceNotifier(overrideState)),
      ],
      child: const MaterialApp(home: Scaffold(floatingActionButton: VoiceFab())),
    );

class _FakeVoiceNotifier extends VoiceNotifier {
  _FakeVoiceNotifier(this._initial);
  final VoiceState _initial;

  @override
  VoiceState build() => _initial;

  @override
  void startListening() {}

  @override
  Future<void> stopAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final ch in [
      'flutter_tts',
      'flutter.baseflow.com/permissions/methods',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(ch),
        (call) async => call.method == 'requestPermissions'
            ? <int, int>{1: 1}
            : null,
      );
    }
  });

  tearDown(() {
    for (final ch in [
      'flutter_tts',
      'flutter.baseflow.com/permissions/methods',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), null);
    }
  });

  group('VoiceFab', () {
    testWidgets('shows mic icon when idle', (tester) async {
      await tester.pumpWidget(_buildFab(VoiceState.idle));
      await tester.pump();
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('shows stop icon when listening', (tester) async {
      await tester.pumpWidget(_buildFab(VoiceState.listening));
      await tester.pump();
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('shows hourglass when processing', (tester) async {
      await tester.pumpWidget(_buildFab(VoiceState.processing));
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('shows volume_up when speaking', (tester) async {
      await tester.pumpWidget(_buildFab(VoiceState.speaking));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('FAB is disabled (onPressed null) when processing',
        (tester) async {
      await tester.pumpWidget(_buildFab(VoiceState.processing));
      await tester.pump();
      final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton));
      expect(fab.onPressed, isNull);
    });
  });
}
