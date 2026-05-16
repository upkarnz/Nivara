import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Snapshot of a user's wake word usage document.
class WakeWordUsageDoc {
  const WakeWordUsageDoc({
    required this.activationsUsed,
    required this.periodStart,
  });

  final int activationsUsed;
  final DateTime periodStart;

  /// Whether the current monthly period has elapsed (≥30 days).
  bool get isNewPeriod =>
      DateTime.now().difference(periodStart).inDays >= 30;

  factory WakeWordUsageDoc.fromMap(Map<String, dynamic> map) {
    return WakeWordUsageDoc(
      activationsUsed: (map['activationsUsed'] as int?) ?? 0,
      periodStart: DateTime.parse(
        (map['periodStart'] as String?) ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  String toString() =>
      'WakeWordUsageDoc(used=$activationsUsed, start=$periodStart)';
}

/// Reads and writes wake word activation counts at `users/{uid}/wakeWordUsage/current`.
class WakeWordQuotaRepository {
  WakeWordQuotaRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _doc = firestore
            .collection('users')
            .doc(uid)
            .collection('wakeWordUsage')
            .doc('current');

  final DocumentReference<Map<String, dynamic>> _doc;

  /// Returns the current wake word usage doc, creating it if absent.
  Future<WakeWordUsageDoc> getUsage() async {
    final snap = await _doc.get();
    final data = snap.data();
    if (data == null) {
      return WakeWordUsageDoc(
        activationsUsed: 0,
        periodStart: DateTime.now(),
      );
    }
    return WakeWordUsageDoc.fromMap(data);
  }

  /// Resets activation count if a new monthly period started (Pro tier).
  /// Does NOT reset for Free tier since Free uses lifetime total.
  Future<void> resetIfNewMonthlyPeriod() async {
    final snap = await _doc.get();
    final data = snap.data();
    if (data == null) {
      await _doc.set({
        'activationsUsed': 0,
        'periodStart': DateTime.now().toIso8601String(),
      });
      return;
    }
    final doc = WakeWordUsageDoc.fromMap(data);
    if (doc.isNewPeriod) {
      await _doc.update({
        'activationsUsed': 0,
        'periodStart': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Increments the activation counter by 1.
  Future<void> incrementActivation() =>
      _doc.update({'activationsUsed': FieldValue.increment(1)});
}

/// Riverpod provider for [WakeWordQuotaRepository].
final wakeWordQuotaRepositoryProvider = Provider<WakeWordQuotaRepository>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('No authenticated user');
  return WakeWordQuotaRepository(
    firestore: FirebaseFirestore.instance,
    uid: user.uid,
  );
});
