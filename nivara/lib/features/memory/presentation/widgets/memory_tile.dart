import 'package:flutter/material.dart';

import '../../domain/memory.dart';

const _typeColors = <String, Color>{
  'personal_fact': Color(0xFF60A5FA),
  'preference': Color(0xFFF472B6),
  'goal': Color(0xFF34D399),
  'work_context': Color(0xFFFB923C),
  'relationship': Color(0xFFA78BFA),
  'routine': Color(0xFF22D3EE),
  'decision': Color(0xFFFBBF24),
  'emotional_signal': Color(0xFFE879F9),
};

class MemoryTile extends StatelessWidget {
  const MemoryTile({
    super.key,
    required this.memory,
    required this.onDelete,
    required this.onEdit,
  });

  final Memory memory;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color =
        _typeColors[memory.memoryType] ?? const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colour dot
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5), blurRadius: 4)
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Content + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.content,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${memory.memoryType.replaceAll('_', ' ')} · '
                  '${(memory.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Edit + Delete buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionBtn(
                icon: Icons.edit_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                tooltip: 'Edit',
                onTap: onEdit,
              ),
              _ActionBtn(
                icon: Icons.delete_outline,
                color: Colors.redAccent.withValues(alpha: 0.7),
                tooltip: 'Forget',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
