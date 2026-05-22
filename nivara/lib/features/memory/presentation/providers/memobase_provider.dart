import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/memobase_repository.dart';

/// MemobaseRepository backed by the Railway proxy.
/// Uses the Firebase ID token for auth — no API key in the app.
final memobaseRepositoryProvider = Provider<MemobaseRepository>((ref) {
  final repo = MemobaseRepository(
    tokenProvider: () => ref.read(firebaseIdTokenProvider.future),
  );
  ref.onDispose(repo.dispose);
  return repo;
});
