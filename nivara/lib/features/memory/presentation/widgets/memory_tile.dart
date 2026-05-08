import 'package:flutter/material.dart';

import '../../domain/memory.dart';

class MemoryTile extends StatelessWidget {
  const MemoryTile({
    super.key,
    required this.memory,
    required this.onDelete,
  });

  final Memory memory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _typeIcon(memory.memoryType),
      title: Text(memory.content),
      subtitle: Text(
        '${memory.memoryType.replaceAll('_', ' ')} · '
        '${(memory.confidence * 100).toStringAsFixed(0)}% confidence',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
        tooltip: 'Forget this',
      ),
    );
  }

  Icon _typeIcon(String type) {
    return switch (type) {
      'preference' => const Icon(Icons.favorite_outline),
      'personal_fact' => const Icon(Icons.person_outline),
      'goal' => const Icon(Icons.flag_outlined),
      'work_context' => const Icon(Icons.work_outline),
      'relationship' => const Icon(Icons.people_outline),
      'routine' => const Icon(Icons.schedule_outlined),
      'decision' => const Icon(Icons.check_circle_outline),
      'emotional_signal' => const Icon(Icons.mood_outlined),
      _ => const Icon(Icons.info_outline),
    };
  }
}
