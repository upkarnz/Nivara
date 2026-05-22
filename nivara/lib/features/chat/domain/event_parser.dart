import 'dart:convert';

/// Holds a parsed schedule event alongside the raw source text that was matched
/// so callers can strip it from the display string.
class ParsedEvent {
  const ParsedEvent({required this.eventMap, required this.source});
  final Map<String, dynamic> eventMap;
  /// The exact substring (fenced block or raw JSON) that was matched.
  final String source;
}

// Returns the inner map of schedule_event if found in content, else null.
Map<String, dynamic>? parseScheduledEvent(String content) =>
    parseScheduledEventFull(content)?.eventMap;

/// Like [parseScheduledEvent] but also returns the matched source string
/// so the caller can remove it from the display content.
ParsedEvent? parseScheduledEventFull(String content) {
  // Match from opening ```json fence to closing ``` fence.
  // dotAll so newlines inside the block are included.
  final fencePattern = RegExp(r'```json(.*?)```', dotAll: true);
  final fenceMatch = fencePattern.firstMatch(content);
  if (fenceMatch != null) {
    final inner = fenceMatch.group(1)!.trim();
    final eventMap = _tryExtract(inner);
    if (eventMap != null) {
      return ParsedEvent(eventMap: eventMap, source: fenceMatch.group(0)!);
    }
  }

  // Fallback: find outermost { ... } using brace counting to handle nesting.
  final start = content.indexOf('{');
  if (start != -1) {
    int depth = 0;
    for (int i = start; i < content.length; i++) {
      if (content[i] == '{') depth++;
      if (content[i] == '}') {
        depth--;
        if (depth == 0) {
          final raw = content.substring(start, i + 1);
          final eventMap = _tryExtract(raw);
          if (eventMap != null) {
            return ParsedEvent(eventMap: eventMap, source: raw);
          }
          break;
        }
      }
    }
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
