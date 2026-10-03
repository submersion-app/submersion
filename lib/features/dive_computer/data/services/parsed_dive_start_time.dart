import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

/// The dive's start as the parser reported it, in wall-clock UTC, or null
/// when the parser reported no usable clock.
///
/// The native layer leaves every date field at 0 when the parser cannot
/// give a datetime (a computer with no clock, a truncated header, a dive
/// with no time reference). `DateTime.utc` does not reject such values: it
/// rolls them over, so year 0, month 0, day 0 becomes `-0001-11-30` and the
/// dive sorts to the start of the logbook (#1640). Any component that would
/// roll over is treated as "no clock" instead, leaving each caller to pick
/// its own fallback.
DateTime? parsedDiveStartTime(pigeon.ParsedDive parsed) {
  final year = parsed.dateTimeYear;
  final month = parsed.dateTimeMonth;
  final day = parsed.dateTimeDay;
  final hour = parsed.dateTimeHour;
  final minute = parsed.dateTimeMinute;
  final second = parsed.dateTimeSecond;
  if (year < 1) return null;
  final start = DateTime.utc(year, month, day, hour, minute, second);
  // A component out of range shows up as a different component after the
  // roll-over, so comparing them back catches every case at once.
  final inRange =
      start.year == year &&
      start.month == month &&
      start.day == day &&
      start.hour == hour &&
      start.minute == minute &&
      start.second == second;
  return inRange ? start : null;
}
