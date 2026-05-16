import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/subscription/data/quota_repository.dart';

void main() {
  group('QuotaDoc.fromMap', () {
    test('parses a valid Firestore map', () {
      final map = {
        'messagesUsed': 42,
        'graceUsed': 1,
        'periodStart': '2026-05-01T00:00:00.000Z',
        'model': 'gemini_flash',
      };
      final doc = QuotaDoc.fromMap(map);
      expect(doc.messagesUsed, 42);
      expect(doc.graceUsed, 1);
      expect(doc.model, 'gemini_flash');
      expect(doc.periodStart, isA<DateTime>());
    });

    test('defaults missing numeric fields to 0', () {
      final map = {
        'periodStart': '2026-05-01T00:00:00.000Z',
        'model': 'gemini_flash',
      };
      final doc = QuotaDoc.fromMap(map);
      expect(doc.messagesUsed, 0);
      expect(doc.graceUsed, 0);
    });

    test('defaults missing model to gemini_flash', () {
      final map = {
        'messagesUsed': 0,
        'graceUsed': 0,
        'periodStart': '2026-05-01T00:00:00.000Z',
      };
      final doc = QuotaDoc.fromMap(map);
      expect(doc.model, 'gemini_flash');
    });
  });

  group('QuotaDoc.isNewPeriod', () {
    test('returns false when period started today', () {
      final doc = QuotaDoc(
        messagesUsed: 0,
        graceUsed: 0,
        periodStart: DateTime.now(),
        model: 'gemini_flash',
      );
      expect(doc.isNewPeriod, isFalse);
    });

    test('returns true when period started more than 30 days ago', () {
      final doc = QuotaDoc(
        messagesUsed: 0,
        graceUsed: 0,
        periodStart: DateTime.now().subtract(const Duration(days: 31)),
        model: 'gemini_flash',
      );
      expect(doc.isNewPeriod, isTrue);
    });
  });
}
