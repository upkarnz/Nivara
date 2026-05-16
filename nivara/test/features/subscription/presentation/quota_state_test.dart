import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/data/quota_repository.dart';
import 'package:nivara/features/subscription/presentation/providers/subscription_providers.dart';

QuotaDoc _doc({int used = 0, int grace = 0, String model = 'gemini_flash'}) {
  return QuotaDoc(
    messagesUsed: used,
    graceUsed: grace,
    periodStart: DateTime.now(),
    model: model,
  );
}

void main() {
  group('QuotaState.fromDoc', () {
    test('remaining is monthlyQuota minus messagesUsed', () {
      final state = QuotaState.fromDoc(doc: _doc(used: 100), monthlyQuota: 3000);
      expect(state.remaining, 2900);
      expect(state.messagesUsed, 100);
      expect(state.monthlyQuota, 3000);
    });

    test('normal state when under quota', () {
      final state = QuotaState.fromDoc(doc: _doc(used: 50), monthlyQuota: 3000);
      expect(state.inGrace, isFalse);
      expect(state.exhausted, isFalse);
    });

    test('inGrace when remaining <= 0 and graceUsed < 3', () {
      final state = QuotaState.fromDoc(doc: _doc(used: 3000, grace: 1), monthlyQuota: 3000);
      expect(state.inGrace, isTrue);
      expect(state.exhausted, isFalse);
      expect(state.graceRemaining, 2);
    });

    test('exhausted when remaining <= 0 and graceUsed >= 3', () {
      final state = QuotaState.fromDoc(doc: _doc(used: 3000, grace: 3), monthlyQuota: 3000);
      expect(state.exhausted, isTrue);
      expect(state.inGrace, isFalse);
      expect(state.graceRemaining, 0);
    });

    test('graceRemaining is 3 - graceUsed', () {
      final state = QuotaState.fromDoc(doc: _doc(used: 3000, grace: 2), monthlyQuota: 3000);
      expect(state.graceRemaining, 1);
    });

    test('remaining can be negative when messagesUsed exceeds quota', () {
      final state = QuotaState.fromDoc(doc: _doc(used: 3100), monthlyQuota: 3000);
      expect(state.remaining, -100);
      // grace=0 means still in grace period, not exhausted yet
      expect(state.inGrace, isTrue);
      expect(state.exhausted, isFalse);
    });
  });
}
