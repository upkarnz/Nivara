import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/event.dart';
import '../providers/planner_provider.dart';
import '../widgets/event_tile.dart';

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(plannerNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF13131F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13131F),
        title: const Text(
          'Planner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () =>
                ref.read(plannerNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text(
            'Failed to load events',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        data: (events) => events.isEmpty
            ? const _EmptyState()
            : _EventList(events: events),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text(
            'No events in the next 30 days',
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(events);
    final days = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayEvents = grouped[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                _dayLabel(day),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...dayEvents.map((e) => EventTile(event: e)),
          ],
        );
      },
    );
  }

  Map<DateTime, List<Event>> _groupByDay(List<Event> events) {
    final map = <DateTime, List<Event>>{};
    for (final e in events) {
      final day =
          DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      (map[day] ??= []).add(e);
    }
    return map;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (day == today) return 'TODAY';
    if (day == tomorrow) return 'TOMORROW';
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final wd = weekdays[day.weekday - 1];
    final mo = months[day.month - 1];
    return '$wd, $mo ${day.day}';
  }
}
