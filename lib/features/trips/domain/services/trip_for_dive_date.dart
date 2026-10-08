import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

/// Pure. The trip among [trips] whose dates cover the calendar day of a dive
/// at [diveDateTime], or null when none does.
///
/// Days are compared, not instants. A dive keeps its wall-clock time in UTC
/// components, so its day is read from those; a trip's dates are local
/// calendar days, start and end inclusive. Comparing epoch milliseconds
/// instead would drop a dive made after midnight's instant on the last day,
/// and shift every dive by the device's offset.
///
/// When trips overlap, the one that started last wins, as with the trip a
/// new dive is offered in the dive editor.
Trip? tripForDiveDate(DateTime diveDateTime, Iterable<Trip> trips) {
  final wall = diveDateTime.toUtc();
  final day = DateTime(wall.year, wall.month, wall.day);
  Trip? best;
  for (final trip in trips) {
    if (day.isBefore(tripDay(trip.startDate)) ||
        day.isAfter(tripDay(trip.endDate))) {
      continue;
    }
    if (best == null || trip.startDate.isAfter(best.startDate)) best = trip;
  }
  return best;
}
