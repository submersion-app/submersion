import 'package:equatable/equatable.dart';

import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

/// A trip's first and last day.
typedef TripDateRange = ({DateTime start, DateTime end});

/// Local midnight of the day a dive at [diveDateTime] was made. A dive keeps
/// its wall-clock time in UTC components, so its day is read from those.
DateTime diveWallClockDay(DateTime diveDateTime) =>
    tripDay(diveDateTime.toUtc());

/// Pure. The dates that keep [start] to [end] and take in every dive at
/// [diveDateTimes], or null when those dates already cover them (issue #3351).
///
/// Days are compared, not instants, as in `tripForDiveDate`, so a stored bound
/// is never moved inward. Only a bound that has to move comes back changed.
TripDateRange? coveringRange({
  required DateTime start,
  required DateTime end,
  required Iterable<DateTime> diveDateTimes,
}) {
  var first = start;
  var last = end;
  for (final dive in diveDateTimes) {
    final day = diveWallClockDay(dive);
    if (day.isBefore(tripDay(first))) first = day;
    if (day.isAfter(tripDay(last))) last = day;
  }
  if (first == start && last == end) return null;
  return (start: first, end: last);
}

/// Pure. Whether saving a dive in the dive editor touched its trip: a new
/// dive on one, a move onto one, or a new day on the one it is on. A dive
/// saved unchanged leaves its trip alone, even if it sits outside it, so an
/// old save never reopens a date the diver set by hand.
bool diveSaveTouchesTrip({
  required String? tripId,
  required String? previousTripId,
  required DateTime date,
  required DateTime? previousDate,
}) {
  if (tripId == null) return false;
  if (tripId != previousTripId || previousDate == null) return true;
  return diveWallClockDay(date) != diveWallClockDay(previousDate);
}

/// One trip whose dates moved to cover its dives, with what undo needs to
/// put them back (issue #3351).
class TripDateStretch extends Equatable {
  const TripDateStretch({
    required this.tripId,
    required this.tripName,
    required this.priorStart,
    required this.priorEnd,
    required this.start,
    required this.end,
    this.isLargerTrip = false,
  });

  final String tripId;
  final String tripName;
  final DateTime priorStart;
  final DateTime priorEnd;
  final DateTime start;
  final DateTime end;

  /// A larger trip moved only because its side trip did.
  final bool isLargerTrip;

  @override
  List<Object?> get props => [
    tripId,
    tripName,
    priorStart,
    priorEnd,
    start,
    end,
    isLargerTrip,
  ];
}

/// The stretch of the dive's own trip among [stretches], if any.
TripDateStretch? ownStretch(Iterable<TripDateStretch> stretches) {
  for (final stretch in stretches) {
    if (!stretch.isLargerTrip) return stretch;
  }
  return null;
}
