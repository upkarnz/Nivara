import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Snapshot of a user's current quota Firestore document.
class QuotaDoc {
  const QuotaDoc({
    required this.messagesUsed,
    required this.graceUsed,
    required this.periodStart,
    required this.model,
  });

  final int messagesUsed;
  final int graceUsed;
  final DateTime periodStart;

  /// Currently active model ID (may differ from tier default if user overrode).
  final String model;

  /// Whether the current billing period has elapsed (≥30 days since [periodStart]).
  bool get isNewPeriod =>
      DateTime.now().difference(periodStart).inDays >= 30;

  factory QuotaDoc.fromMap(Map<String, dynamic> map) {
    return QuotaDoc(
      messagesUsed: (map['messagesUsed'] as int?) ?? 0,
      graceUsed: (map['graceUsed'] as int?) ?? 0,
      periodStart: DateTime.parse(
        (map['periodStart'] as String?) ??
            DateTime.now().toIso8601String(),
      ),
      model: (map['model'] as String?) ?? 'gemini_flash',
    );
  }

  @override
  String toString() =>
      'QuotaDoc(used=$messagesUsed, grace=$graceUsed, model=$model, start=$periodStart)';
}

/// Abstract interface for quota read/write operations.
/// Concrete implementation: [FirestoreQuotaRepository].
/// Tests can extend this directly without needing Firebase.
abstract class QuotaRepository {
  const QuotaRepository();

  Stream<QuotaDoc> getQuota();
  Future<void> resetIfNewPeriod();
  Future<void> incrementMessage();
  Future<void> incrementGrace();
  Future<void> setModel(String model);
}

/// Firestore-backed implementation of [QuotaRepository].
/// Reads and writes the user's quota document at `users/{uid}/quota/current`.
class FirestoreQuotaRepository extends QuotaRepository {
  FirestoreQuotaRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _doc = firestore
            .collection('users')
            .doc(uid)
            .collection('quota')
            .doc('current');

  final DocumentReference<Map<String, dynamic>> _doc;

  /// Stream of quota snapshots. Emits on every remote change.
  @override
  Stream<QuotaDoc> getQuota() {
    return _doc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) {
        // First-ever document — return defaults.
        return QuotaDoc(
          messagesUsed: 0,
          graceUsed: 0,
          periodStart: DateTime.now(),
          model: 'gemini_flash',
        );
      }
      return QuotaDoc.fromMap(data);
    });
  }

  /// Resets `messagesUsed` and `graceUsed` to 0 if a new billing period started.
  @override
  Future<void> resetIfNewPeriod() async {
    final snap = await _doc.get();
    final data = snap.data();
    if (data == null) {
      // Initialise document.
      await _doc.set({
        'messagesUsed': 0,
        'graceUsed': 0,
        'periodStart': DateTime.now().toIso8601String(),
        'model': 'gemini_flash',
      });
      return;
    }
    final doc = QuotaDoc.fromMap(data);
    if (doc.isNewPeriod) {
      await _doc.update({
        'messagesUsed': 0,
        'graceUsed': 0,
        'periodStart': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Increments the normal message counter by 1.
  @override
  Future<void> incrementMessage() =>
      _doc.update({'messagesUsed': FieldValue.increment(1)});

  /// Increments the grace message counter by 1.
  @override
  Future<void> incrementGrace() =>
      _doc.update({'graceUsed': FieldValue.increment(1)});

  /// Persists the user's chosen model override to Firestore.
  @override
  Future<void> setModel(String model) =>
      _doc.update({'model': model});
}

/// Riverpod provider for [QuotaRepository], scoped to the authenticated user.
final quotaRepositoryProvider = Provider<QuotaRepository>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('No authenticated user');
  return FirestoreQuotaRepository(
    firestore: FirebaseFirestore.instance,
    uid: user.uid,
  );
});
