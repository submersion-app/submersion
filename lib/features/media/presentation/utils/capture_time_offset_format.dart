/// Formats a capture-time correction for display.
///
/// Deliberately locale-independent digits with bare `h` and `m` units: the
/// value is a duration knob the diver is dialling, not a timestamp, and the
/// surrounding label carries the translated prose.
String formatSignedOffset(Duration offset) {
  if (offset == Duration.zero) return '0m';
  final sign = offset.isNegative ? '-' : '+';
  return '$sign${formatOffsetMagnitude(offset)}';
}

/// The absolute size of [offset], with no sign.
///
/// Used where the direction is already carried by the surrounding sentence,
/// such as "3h 38m after the nearest dive".
String formatOffsetMagnitude(Duration offset) {
  final abs = offset.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}
