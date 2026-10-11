import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// An inclusive range of calendar days. Both ends are local dates at
/// midnight, the way [DiveFilterState.startDate] and
/// [DiveFilterState.endDate] are read: only the year, month and day count.
typedef DayRange = ({DateTime start, DateTime end});

/// [date] with its time of day dropped.
DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Whole days from [from] to [to]. Counted between UTC dates, so a daylight
/// saving change in between never gains or loses a day.
int dayIndex(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The calendar day [days] after [from], built from its parts: adding a
/// Duration would land an hour off across a daylight saving change.
DateTime dayAt(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);

/// [range] as calendar days held inside [span], start never after end.
DayRange clampDays(DayRange range, DayRange span) {
  DateTime clamp(DateTime date) {
    final day = calendarDay(date);
    if (day.isBefore(span.start)) return span.start;
    if (day.isAfter(span.end)) return span.end;
    return day;
  }

  final start = clamp(range.start);
  final end = clamp(range.end);
  return (start: start.isAfter(end) ? end : start, end: end);
}

/// The days the connections [filter] covers within the log's [span]. No
/// start or end date means the span's own first or last day. The timeline
/// and its play sweep both read the range this way.
DayRange filteredDays(DiveFilterState filter, DayRange span) => clampDays((
  start: filter.startDate ?? span.start,
  end: filter.endDate ?? span.end,
), span);

/// [filter] narrowed to [range]. An end at the edge of the span is left
/// open rather than stored as a bound: an open end keeps dives logged later
/// on the map, and the whole span is no date filter at all.
DiveFilterState filterWithDays(
  DiveFilterState filter,
  DayRange range,
  DayRange span,
) {
  final days = clampDays(range, span);
  final openStart = !days.start.isAfter(span.start);
  final openEnd = !days.end.isBefore(span.end);
  return filter.copyWith(
    startDate: openStart ? null : days.start,
    clearStartDate: openStart,
    endDate: openEnd ? null : days.end,
    clearEndDate: openEnd,
  );
}
