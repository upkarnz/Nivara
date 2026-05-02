import 'package:flutter/material.dart';
import '../../domain/event.dart';

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});

  final Event event;

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
    return Container(
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
          ],
        ),
      ),
    );
  }
}
