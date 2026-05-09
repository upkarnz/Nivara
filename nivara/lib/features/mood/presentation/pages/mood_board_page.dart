import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/mood_entry.dart';
import '../providers/mood_provider.dart';

const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

Color _barColor(int score) {
  const colors = [
    Color(0xFF3B0764), // 1 — dark purple
    Color(0xFF6B21A8), // 2
    Color(0xFF7C3AED), // 3
    Color(0xFF8B5CF6), // 4
    Color(0xFFA78BFA), // 5 — bright purple
  ];
  return colors[(score - 1).clamp(0, 4)];
}

String _avgLabel(double avg) {
  if (avg < 1.5) return '😔 Rough week';
  if (avg < 2.5) return '😐 Low energy';
  if (avg < 3.5) return '🙂 Okay week';
  if (avg < 4.5) return '😄 Good week';
  return '🤩 Amazing week';
}

class MoodBoardPage extends ConsumerWidget {
  const MoodBoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(weekMoodProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mood Board')),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (week) => _MoodBoardBody(week: week),
      ),
    );
  }
}

class _MoodBoardBody extends StatelessWidget {
  const _MoodBoardBody({required this.week});

  final List<MoodEntry?> week;

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1;
    final entries = week.whereType<MoodEntry>().toList();
    final hasData = entries.isNotEmpty;
    final avg = hasData
        ? entries.map((e) => e.score).reduce((a, b) => a + b) / entries.length
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final entry = week[i];
              final isToday = i == todayIdx;
              return Expanded(
                child: Column(
                  children: [
                    Opacity(
                      opacity: entry == null ? 0.2 : 1.0,
                      child: Text(
                        entry?.emoji ?? '❓',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _days[i],
                      style: TextStyle(
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? const Color(0xFF7C3AED)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final entry = week[i];
                if (entry == null) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                }
                final h = (entry.score / 5 * 120).clamp(24, 120).toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: _barColor(entry.score),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (hasData)
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Week avg: ${_avgLabel(avg)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
