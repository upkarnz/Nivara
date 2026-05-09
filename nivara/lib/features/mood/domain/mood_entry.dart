enum MoodSource { passive, checkin }

class MoodEntry {
  const MoodEntry({
    required this.date,
    required this.score,
    required this.label,
    required this.source,
  });

  final DateTime date;
  final int score;
  final String label;
  final MoodSource source;

  String get emoji {
    switch (score) {
      case 1:
        return '😔';
      case 2:
        return '😐';
      case 3:
        return '🙂';
      case 4:
        return '😄';
      case 5:
        return '🤩';
      default:
        return '❓';
    }
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'score': score,
        'label': label,
        'source': source.name,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        date: DateTime.parse(json['date'] as String),
        score: json['score'] as int,
        label: json['label'] as String,
        source: MoodSource.values.byName(json['source'] as String),
      );
}
