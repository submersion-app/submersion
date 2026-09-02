/// Tooltip text for a gas time remaining sample.
///
/// Whole minutes, rounded down: a countdown must never overstate what is
/// left. [blank] stands in where the computer or the calculation blanked the
/// value (surface, SAC window not yet full, deco in force).
String formatGtrMinutes(
  int? seconds, {
  required String minuteUnit,
  String blank = '--',
}) {
  if (seconds == null) return blank;
  return '${seconds ~/ 60} $minuteUnit';
}
