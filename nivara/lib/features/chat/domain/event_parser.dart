import 'dart:convert';

// Returns the inner map of schedule_event if found in content, else null.
Map<String, dynamic>? parseScheduledEvent(String content) {
  // Try code-fence block first: ```json ... ```
  final fencePattern = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
  final fenceMatch = fencePattern.firstMatch(content);
  if (fenceMatch != null) {
    return _tryExtract(fenceMatch.group(1)!);
  }

  // Fallback: find first { ... } in content
  final start = content.indexOf('{');
  final end = content.lastIndexOf('}');
  if (start != -1 && end > start) {
    return _tryExtract(content.substring(start, end + 1));
  }

  return null;
}

Map<String, dynamic>? _tryExtract(String raw) {
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final inner = decoded['schedule_event'];
    if (inner is Map<String, dynamic>) return inner;
  } on FormatException {
    // malformed JSON
  }
  return null;
}
