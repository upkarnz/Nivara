class Memory {
  const Memory({
    required this.id,
    required this.uid,
    required this.content,
    required this.memoryType,
    required this.confidence,
    required this.createdAt,
    required this.lastReinforced,
    required this.reinforcementCount,
  });

  final String id;
  final String uid;
  final String content;
  final String memoryType;
  final double confidence;
  final String createdAt;
  final String lastReinforced;
  final int reinforcementCount;

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String,
        uid: json['uid'] as String,
        content: json['content'] as String,
        memoryType: json['memory_type'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        createdAt: json['created_at'] as String,
        lastReinforced: json['last_reinforced'] as String,
        reinforcementCount: json['reinforcement_count'] as int,
      );
}
