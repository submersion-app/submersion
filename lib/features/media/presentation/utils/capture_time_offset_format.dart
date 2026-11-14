import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';

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
/// Used where the direction is already carried by the surrounding label, such
/// as the capture-time correction bar's step-forward and step-back tooltips.
String formatOffsetMagnitude(Duration offset) {
  final abs = offset.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

/// The size of a media time shift of [seconds], with no sign.
///
/// Under an hour it reads as the Set-time dialog's own minutes:seconds, the
/// unit the diver is dialling there. From an hour up it takes the bare units
/// of [formatOffsetMagnitude], with days, so a camera on another time zone
/// or another date reads as what it is and not as a count of minutes.
String formatShiftMagnitude(int seconds) {
  final abs = seconds.abs();
  if (abs < Duration.secondsPerHour) return formatElapsedMmSs(abs);
  final days = abs ~/ Duration.secondsPerDay;
  final hours = abs % Duration.secondsPerDay ~/ Duration.secondsPerHour;
  final minutes = abs % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
  final secs = abs % Duration.secondsPerMinute;
  String padded(int value) => value.toString().padLeft(2, '0');
  return [
    if (days > 0) '${days}d',
    '${hours}h',
    '${padded(minutes)}m',
    if (secs > 0) '${padded(secs)}s',
  ].join(' ');
}
