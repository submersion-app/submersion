// Up to five digits of minutes (69 days): no dive is longer, and a longer run
// is text int.parse refuses or a count that overflows when scaled to seconds.
final RegExp _minutesSeconds = RegExp(r'^(\d{1,5})(?::([0-5]?\d))?$');

/// Seconds for a `minutes:seconds` text, or bare minutes; null when the
/// text is not a time ("ab", "1:60", "", a minutes run over five digits).
int? parseMinutesSeconds(String text) {
  final match = _minutesSeconds.firstMatch(text.trim());
  if (match == null) return null;
  final minutes = int.parse(match.group(1)!);
  final seconds = match.group(2);
  return minutes * 60 + (seconds == null ? 0 : int.parse(seconds));
}

/// `m:ss` for a count of seconds: 750 is "12:30", 67 is "1:07". The one
/// shape a time from the dive's start is shown in, on a gas switch and in
/// the field that edits one.
String formatMinutesSeconds(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
