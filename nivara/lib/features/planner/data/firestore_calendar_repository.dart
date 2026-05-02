import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/calendar_repository.dart';
import '../domain/event.dart';

part 'firestore_calendar_repository.g.dart';

@riverpod
FirestoreCalendarRepository firestoreCalendarRepository(
    // ignore: deprecated_member_use_from_same_package
    FirestoreCalendarRepositoryRef ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('No authenticated user');
  return FirestoreCalendarRepository(
    firestore: FirebaseFirestore.instance,
    userId: user.uid,
  );
}

class FirestoreCalendarRepository implements CalendarRepository {
  FirestoreCalendarRepository(
      {required FirebaseFirestore firestore, required this.userId})
      : _col =
            firestore.collection('users').doc(userId).collection('events');

  final String userId;
  final CollectionReference<Map<String, dynamic>> _col;

  @override
  Stream<List<Event>> watchEvents(
          {required DateTime from, required DateTime to}) =>
      _col
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(from),
              isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('startTime')
          .snapshots()
          .map((snap) => snap.docs.map(_fromDoc).toList());

  @override
  Future<Event> createEvent(Event event) async {
    final now = DateTime.now();
    final data = _toFirestoreData(event.copyWith(updatedAt: now));
    data['createdAt'] = Timestamp.fromDate(now);
    final ref = await _col.add(data);
    return event.copyWith(id: ref.id, updatedAt: now);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final data = _toFirestoreData(event.copyWith(updatedAt: DateTime.now()));
    await _col.doc(event.id).update(data);
  }

  @override
  Future<void> deleteEvent(String eventId) => _col.doc(eventId).delete();

  Event _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Event(
      id: doc.id,
      userId: userId,
      title: d['title'] as String,
      startTime: (d['startTime'] as Timestamp).toDate(),
      endTime: (d['endTime'] as Timestamp).toDate(),
      description: d['description'] as String?,
      location: d['location'] as String?,
      source: EventSource.values.byName(d['source'] as String),
      googleEventId: d['googleEventId'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: (d['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _toFirestoreData(Event event) => {
        'userId': event.userId,
        'title': event.title,
        'startTime': Timestamp.fromDate(event.startTime),
        'endTime': Timestamp.fromDate(event.endTime),
        'description': event.description,
        'location': event.location,
        'source': event.source.name,
        'googleEventId': event.googleEventId,
        'updatedAt': Timestamp.fromDate(event.updatedAt),
      };
}
