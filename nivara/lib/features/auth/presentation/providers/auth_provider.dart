import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth_repository.dart';

part 'auth_provider.g.dart';

@riverpod
Stream<User?> authState(AuthStateRef ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
}

@riverpod
Future<String> firebaseIdToken(FirebaseIdTokenRef ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  return repo.getIdToken();
}
