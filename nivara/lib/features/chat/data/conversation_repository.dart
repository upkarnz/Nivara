import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/message.dart';

part 'conversation_repository.g.dart';

@riverpod
ConversationRepository conversationRepository(ConversationRepositoryRef ref) =>
    ConversationRepository();

class ConversationRepository {
  ConversationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _convCollection(String uid) =>
      _db.collection('users').doc(uid).collection('conversations');

  Future<String> createConversation(String uid) async {
    final doc = await _convCollection(uid).add({
      'messages': [],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return doc.id;
  }

  Future<void> appendMessage(
    String uid,
    String conversationId,
    ChatMessage message,
  ) =>
      _convCollection(uid).doc(conversationId).update({
        'messages': FieldValue.arrayUnion([
          {
            'role': message.role.name,
            'content': message.content,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
}
