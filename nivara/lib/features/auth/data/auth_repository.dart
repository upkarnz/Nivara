import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository();

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in aborted');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createAccount(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<String> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user');
    return await user.getIdToken() ?? '';
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  /// Permanently deletes the account. Wipes all Firestore user data first,
  /// then removes the Firebase Auth record.
  ///
  /// Throws [FirebaseAuthException] with code `requires-recent-login` if the
  /// user's session is stale — the caller should ask them to sign out and back
  /// in, then retry.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user');

    // Best-effort: delete all known Firestore subcollections under users/{uid}.
    // Subcollections (profile, assistant, events, conversations, …) must be
    // individually removed — deleting the parent doc does NOT cascade.
    final db = FirebaseFirestore.instance;
    final uid = user.uid;

    Future<void> deleteCollection(String path) async {
      try {
        final snap = await db.collection(path).limit(200).get();
        final batch = db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (_) {
        // Non-fatal: server-side cleanup jobs can handle orphaned docs.
      }
    }

    await Future.wait([
      deleteCollection('users/$uid/profile'),
      deleteCollection('users/$uid/assistant'),
      deleteCollection('users/$uid/events'),
      deleteCollection('users/$uid/conversations'),
      deleteCollection('users/$uid/mood'),
      deleteCollection('users/$uid/quota'),
    ]);

    // Delete the top-level user document if it exists.
    try {
      await db.collection('users').doc(uid).delete();
    } catch (_) {}

    // Delete Firebase Auth account — may throw requires-recent-login.
    await user.delete();
    await _googleSignIn.signOut();
  }
}
