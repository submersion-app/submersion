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

/// Pure. Whether a trip day is a dive day: its itinerary row says so, or it
/// has no row. An itinerary may cover only some days (a single planned day
/// from the board, decided 2026-09-29), so a day it does not cover is an
/// ordinary dive day, and a trip with no itinerary at all is all dive days.
bool isTripDiveDay(ItineraryDay? row) =>
    row == null || row.dayType == DayType.diveDay;

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
