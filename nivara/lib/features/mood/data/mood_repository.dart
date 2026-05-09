import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/mood_entry.dart';

class MoodRepository {
  static const _key = 'mood_entries';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<MoodEntry>> getAll() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return MoodEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<MoodEntry>()
        .toList();
  }

  Future<void> save(MoodEntry entry) async {
    final all = await getAll();
    final dateKey = _dateKey(entry.date);

    final existingIndex = all.indexWhere((e) => _dateKey(e.date) == dateKey);

    if (existingIndex != -1) {
      final existing = all[existingIndex];
      if (existing.source == MoodSource.checkin && entry.source == MoodSource.passive) {
        return;
      }
      all[existingIndex] = entry;
    } else {
      all.add(entry);
    }

    final prefs = await _prefs;
    await prefs.setStringList(
      _key,
      all.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<MoodEntry?> getToday() async {
    final all = await getAll();
    final todayKey = _dateKey(DateTime.now());
    try {
      return all.lastWhere((e) => _dateKey(e.date) == todayKey);
    } catch (_) {
      return null;
    }
  }

  /// Returns a 7-element list for Mon–Sun of the current ISO week.
  /// Null means no data for that day.
  Future<List<MoodEntry?>> getWeek() async {
    final all = await getAll();
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key = _dateKey(day);
      try {
        return all.lastWhere((e) => _dateKey(e.date) == key);
      } catch (_) {
        return null;
      }
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
