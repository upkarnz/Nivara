import 'package:flutter/material.dart';
import '../../domain/event.dart';

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.onDelete});

  final Event event;
  final VoidCallback? onDelete;

  Color get _borderColor => switch (event.source) {
        EventSource.googleCalendar => const Color(0xFF4285F4),
        EventSource.local => const Color(0xFF7C6EF7),
        EventSource.synced => const Color(0xFF4CAF50),
      };

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }

  String get _timeLabel {
    final start = _formatTime(event.startTime);
    final durMin = event.endTime.difference(event.startTime).inMinutes;
    final dur = durMin >= 60
        ? '${durMin ~/ 60} hr${durMin ~/ 60 > 1 ? 's' : ''}'
        : '$durMin min';
    return '$start · $dur';
  }

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('event_tile_border'),
              width: 3,
              decoration: BoxDecoration(
                color: _borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeLabel,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white38, size: 20),
                onPressed: () => _confirmDelete(context),
                tooltip: 'Delete event',
              ),
          ],
        ),
      ),
    );

    if (onDelete == null) return tile;

    return Dismissible(
      key: Key('event_${event.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _showDeleteDialog(context),
      onDismissed: (_) => onDelete!(),
      child: tile,
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Remove "${event.title}" from your planner?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    _showDeleteDialog(context).then((confirmed) {
      if (confirmed == true) onDelete!();
    });
  }
}
