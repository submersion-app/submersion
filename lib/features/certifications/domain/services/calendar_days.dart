/// Calendar-day arithmetic for currency clocks (issue #2267).
///
/// Intervals here run from 30 to 1095 days, so a window straddling a local
/// DST transition is near certain. `Duration(days: n)` adds 24-hour blocks
/// and lands an hour off across one; these build dates from components.
library;

/// The calendar day of [t], from its own components. A UTC-flagged dive
/// wall clock keeps its digits, exactly as daysSinceLastDiveProvider reads
/// it.
DateTime calendarDay(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime addCalendarDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
/// Counted on UTC dates so no local offset change can shave an hour off.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inHours ~/ 24;
}
