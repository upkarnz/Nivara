enum EventSource { local, googleCalendar, synced }

class Event {
  const Event({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.location,
    required this.source,
    this.googleEventId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final String? location;
  final EventSource source;
  final String? googleEventId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Event.fromJson(Map<String, dynamic> json) {
    final start = DateTime.parse(json['startTime'] as String);
    final end = json['endTime'] != null
        ? DateTime.parse(json['endTime'] as String)
        : start.add(const Duration(hours: 1));
    return Event(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String,
      title: json['title'] as String,
      startTime: start,
      endTime: end,
      description: json['description'] as String?,
      location: json['location'] as String?,
      source: EventSource.values.byName(
        (json['source'] as String?) ?? EventSource.local.name,
      ),
      googleEventId: json['googleEventId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'title': title,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'description': description,
        'location': location,
        'source': source.name,
        'googleEventId': googleEventId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Event copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? location,
    EventSource? source,
    String? googleEventId,
    DateTime? updatedAt,
  }) =>
      Event(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        description: description ?? this.description,
        location: location ?? this.location,
        source: source ?? this.source,
        googleEventId: googleEventId ?? this.googleEventId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
