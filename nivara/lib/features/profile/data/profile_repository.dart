import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/models/user_profile.dart';

part 'profile_repository.g.dart';

@riverpod
ProfileRepository profileRepository(ProfileRepositoryRef ref) =>
    ProfileRepository();

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _db.collection('users').doc(uid).collection('profile').doc('data');

  DocumentReference<Map<String, dynamic>> _assistantDoc(String uid) =>
      _db.collection('users').doc(uid).collection('assistant').doc('data');

  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _profileDoc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(snap.data()!);
  }

  Future<void> saveProfile(String uid, UserProfile profile) =>
      _profileDoc(uid).set(profile.toMap(), SetOptions(merge: true));

  Future<AssistantConfig?> getAssistant(String uid) async {
    final snap = await _assistantDoc(uid).get();
    if (!snap.exists) return null;
    return AssistantConfig.fromMap(snap.data()!);
  }

  Future<void> saveAssistant(String uid, AssistantConfig config) =>
      _assistantDoc(uid).set(config.toMap(), SetOptions(merge: true));
}
