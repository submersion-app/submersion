import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A trip's itinerary days, held in its sitting (issue #4527, phase 3):
/// read from and written through [repository] (the app's provider where
/// there is one, so a test can stand in for it).
///
/// What the list holds lives in the sitting under its key, so every list
/// made by this function is the same list; the repository is only how it
/// reads and writes.
///
/// At Save the days the sitting added are written with `saveAll`, keeping
/// the ids the sitting gave them (but not over a date stored meanwhile),
/// and each day it changed with `updateDay`.
/// No day is removed in a sitting, as none is on the page today; the plan
/// days the trip's dates leave behind go in the trip's save service.
SittingList<Trip, ItineraryDay> tripItineraryDays([
  ItineraryDayRepository? repository,
]) => _itineraryList(repository ?? ItineraryDayRepository());

SittingList<Trip, ItineraryDay> _itineraryList(
  ItineraryDayRepository repository,
) => SittingList<Trip, ItineraryDay>(
  key: 'trip.itinerary',
  cardId: TripCardId.itineraryDays.name,
  read: (trip) => repository.getByTripId(trip.id),
  write: (trip, loaded, current) async {
    final before = {for (final d in loaded) d.id: d};
    // A day stored meanwhile for a date the sitting generated one for
    // (another device's) stands: the table does not stop two rows a date.
    final stored = {
      for (final d in await repository.getByTripId(trip.id)) tripDay(d.date),
    };
    final added = [
      for (final d in current)
        if (!before.containsKey(d.id) && !stored.contains(tripDay(d.date))) d,
    ];
    final changed = [
      for (final d in current)
        if (before[d.id] case final was? when was != d) d,
    ];
    if (added.isNotEmpty) await repository.saveAll(added);
    for (final day in changed) {
      await repository.updateDay(day);
    }
    return added.isNotEmpty || changed.isNotEmpty;
  },
);

/// The days [trip]'s dates have no row for in [days], generated for its
/// type: what the Generate button adds.
List<ItineraryDay> missingItineraryDays(List<ItineraryDay> days, Trip trip) {
  final covered = {for (final d in days) tripDay(d.date)};
  return ItineraryDay.generateForTrip(
    tripId: trip.id,
    startDate: trip.startDate,
    endDate: trip.endDate,
    tripType: trip.tripType,
  ).where((d) => !covered.contains(tripDay(d.date))).toList();
}

/// [days] with [added] among them, in date order, one day a date: an added
/// day for a date [days] (or an earlier added day) already has is left out,
/// so Generate tapped twice before the page redraws adds each day once.
List<ItineraryDay> withDaysAdded(
  List<ItineraryDay> days,
  List<ItineraryDay> added,
) {
  final covered = {for (final d in days) tripDay(d.date)};
  return [
    ...days,
    for (final d in added)
      if (covered.add(tripDay(d.date))) d,
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// [days] with [date]'s planned dives set to [planned], as the cylinder
/// board's forecast strip sets them (`ItineraryDayRepository.setPlannedDives`):
/// every day of that date takes it, a plan of 0 turns a dive day into a rest
/// day and any other plan (or none) turns a rest day back, other types
/// keep. A date with no day gets one, numbered from [trip]'s start and typed
/// dive day (rest day for 0), with an id from [newId]; null on such a date
/// adds nothing.
List<ItineraryDay> withPlannedDives(
  List<ItineraryDay> days,
  Trip trip,
  DateTime date,
  int? planned, {
  required String Function() newId,
  required DateTime now,
}) {
  final day = tripDay(date);
  if (days.any((d) => tripDay(d.date) == day)) {
    final from = planned == 0 ? DayType.diveDay : DayType.rest;
    final to = planned == 0 ? DayType.rest : DayType.diveDay;
    return [
      for (final d in days)
        if (tripDay(d.date) == day)
          d.copyWith(
            plannedDives: planned,
            dayType: d.dayType == from ? to : d.dayType,
          )
        else
          d,
    ];
  }
  if (planned == null) return days;
  return [
    ...days,
    ItineraryDay(
      id: newId(),
      tripId: trip.id,
      dayNumber: calendarDaysBetween(trip.startDate, day) + 1,
      date: day,
      dayType: planned == 0 ? DayType.rest : DayType.diveDay,
      plannedDives: planned,
      createdAt: now,
      updatedAt: now,
    ),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// [days] with the day [edited] is a copy of taking what the day sheet
/// edits from it: the type, the place, the notes and the planned dives.
/// The sheet is handed a day numbered for the page, so its number is not
/// taken.
List<ItineraryDay> withDayEdited(
  List<ItineraryDay> days,
  ItineraryDay edited,
) => [
  for (final d in days)
    if (d.id == edited.id)
      d.copyWith(
        dayType: edited.dayType,
        portName: edited.portName,
        notes: edited.notes,
        plannedDives: edited.plannedDives,
      )
    else
      d,
];
