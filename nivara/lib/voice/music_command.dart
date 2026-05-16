/// All music actions that can be triggered by voice without an LLM call.
enum MusicCommand {
  play,
  pause,
  resume,
  skip,
  stop,
  playCalmCategory,
  playEnergizedCategory,
}

/// Returns the matching [MusicCommand] for [transcript], or null if the
/// transcript does not describe a music command.
/// Comparison is case-insensitive.
MusicCommand? matchMusicCommand(String transcript) {
  final lower = transcript.toLowerCase().trim();
  if (lower.isEmpty) return null;

  // Order matters: more specific phrases checked first.
  if (lower.contains('turn off music')) return MusicCommand.stop;
  if (lower.contains('play music') || lower.contains('start music')) {
    return MusicCommand.play;
  }
  if (lower.contains('stop music') || lower == 'pause') {
    return MusicCommand.pause;
  }
  if (lower.contains('skip') || lower.contains('next song')) {
    return MusicCommand.skip;
  }
  if (lower.contains('resume') || lower.contains('continue playing')) {
    return MusicCommand.resume;
  }
  if (lower.contains('calmer') ||
      lower.contains('relaxing') ||
      lower.contains('calm down')) {
    return MusicCommand.playCalmCategory;
  }
  if (lower.contains('upbeat') || lower.contains('energize')) {
    return MusicCommand.playEnergizedCategory;
  }
  return null;
}
