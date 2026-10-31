/// h:mm text for a [duration], as surface intervals are shown: 1:05, 24:00.
String formatHoursMinutes(Duration duration) {
  final minutes = duration.inMinutes;
  final hours = minutes ~/ 60;
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '$hours:$rest';
}

/// Parses h:mm text into a duration: `1:30`, `0:05`, `:45`, or bare hours
/// such as `2`. Null for anything else, including minutes past 59 and more
/// hours than six digits hold.
Duration? parseHoursMinutes(String text) {
  final match = RegExp(
    r'^\s*(\d{0,6})\s*(?::\s*(\d{1,2}))?\s*$',
  ).firstMatch(text);
  if (match == null) return null;
  final hoursText = match.group(1)!;
  final minutesText = match.group(2);
  if (hoursText.isEmpty && minutesText == null) return null;
  final hours = hoursText.isEmpty ? 0 : int.parse(hoursText);
  final minutes = minutesText == null ? 0 : int.parse(minutesText);
  if (minutes > 59) return null;
  return Duration(hours: hours, minutes: minutes);
}
