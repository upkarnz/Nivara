import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:nivara/features/auth/data/auth_repository.dart';

import 'auth_repository_test.mocks.dart';

@GenerateMocks([FirebaseAuth, UserCredential, User])
void main() {
  late MockFirebaseAuth mockAuth;
  late AuthRepository repo;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    repo = AuthRepository(auth: mockAuth);
  });

  test('authStateChanges delegates to FirebaseAuth.authStateChanges', () {
    final stream = const Stream<User?>.empty();
    when(mockAuth.authStateChanges()).thenAnswer((_) => stream);
    expect(repo.authStateChanges, equals(stream));
    verify(mockAuth.authStateChanges()).called(1);
  });

  test('currentUser returns null when not signed in', () {
    when(mockAuth.currentUser).thenReturn(null);
    expect(repo.currentUser, isNull);
  });
}
