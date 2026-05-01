import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

part 'profile_provider.g.dart';

@riverpod
Future<UserProfile?> userProfile(UserProfileRef ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(user.uid);
}

@riverpod
Future<AssistantConfig?> assistantConfig(AssistantConfigRef ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getAssistant(user.uid);
}
