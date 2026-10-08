import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

/// Local midnight of [date]'s calendar day.
DateTime tripDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Every calendar day from [from] to [to], inclusive, by calendar arithmetic
/// so a daylight-saving change never drops or repeats a day. Empty when
/// [from] is after [to].
List<DateTime> tripDaysBetween(DateTime from, DateTime to) {
  final first = tripDay(from);
  final last = tripDay(to);
  return [
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
}

/// The itinerary row for each day, keyed by [tripDay].
Map<DateTime, ItineraryDay> itineraryByDay(List<ItineraryDay> itinerary) => {
  for (final d in itinerary) tripDay(d.date): d,
};

/// Pure. Whether a trip day is a dive day: the diver's own plan for it when
/// they set one (a Travel day planned at 2 is a dive day, a dive day planned
/// at 0 is not, #2845), else its type, else, with no row, yes. An itinerary
/// may cover only some days (a single planned day from the board, decided
/// 2026-09-29), so a day it does not cover is an ordinary dive day, and a
/// trip with no itinerary at all is all dive days.
bool isTripDiveDay(ItineraryDay? row) {
  if (row == null) return true;
  final planned = row.plannedDives;
  if (planned != null) return planned > 0;
  return row.dayType == DayType.diveDay;
}

/// Pure. The type a day reads as: its stored type, except that a rest day
/// with a dive logged on it reads as a dive day (#2875), the way the trip
/// story reads a day planned at none that was dived anyway. Display only:
/// the row keeps its stored type, so removing the dive brings Rest back.
DayType shownDayType(ItineraryDay row, {required bool hasDives}) =>
    row.dayType == DayType.rest && hasDives ? DayType.diveDay : row.dayType;

/// Pure. Whether an itinerary row carries nothing but a plan: a dive day,
/// or the rest day the board writes for a plan of 0 (#2658), with no port,
/// position or notes. Its planned dive count is the plan
/// itself, which means nothing outside the trip's dates, so such a row
/// outside them holds nothing the trip still has. A blank port or note is
/// no content: sync and import write the columns unnormalized, and the
/// story already reads whitespace as absent.
bool isBarePlanDay(ItineraryDay row) =>
    (row.dayType == DayType.diveDay || row.dayType == DayType.rest) &&
    (row.portName ?? '').trim().isEmpty &&
    row.latitude == null &&
    row.longitude == null &&
    row.notes.trim().isEmpty;

/// Pure. The trip's dive days from [start] to [end] under [isTripDiveDay];
/// itinerary rows outside the trip are ignored.
int tripDiveDayCount({
  required DateTime start,
  required DateTime end,
  required List<ItineraryDay> itinerary,
}) {
  final byDay = itineraryByDay(itinerary);
  return tripDaysBetween(
    start,
    end,
  ).where((d) => isTripDiveDay(byDay[d])).length;
}
