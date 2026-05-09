import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../domain/mood_entry.dart';
import '../providers/mood_provider.dart';

class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  static const _emojis = ['😔', '😐', '🙂', '😄', '🤩'];
  static const _labels = ['awful', 'bad', 'okay', 'good', 'great'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(assistantConfigProvider);
    final name = configAsync.valueOrNull?.name ?? (configAsync.isLoading ? '...' : 'Rocky');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3F),
        border: Border.all(color: const Color(0xFF4C1D95)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '☀️ Good morning, $name — How are you feeling today?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_emojis.length, (index) {
              return Semantics(
                label: _labels[index],
                button: true,
                child: GestureDetector(
                  onTap: () async { await _onEmojiTap(ref, index); },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Text(_emojis[index], style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _onEmojiTap(WidgetRef ref, int index) async {
    final score = index + 1;
    final label = _labels[index];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entry = MoodEntry(
      date: today,
      score: score,
      label: label,
      source: MoodSource.checkin,
    );
    try {
      final repo = ref.read(moodRepositoryProvider);
      await repo.save(entry);
      ref.invalidate(weekMoodProvider);
      ref.invalidate(todayMoodProvider);
      onDismiss();
    } catch (_) {
      // Non-critical: save failure must not crash the card
    }
  }
}
