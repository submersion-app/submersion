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
/// the ids the sitting gave them, and each day it changed with `updateDay`.
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
    final added = [
      for (final d in current)
        if (!before.containsKey(d.id)) d,
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

/// [days] with the days [working]'s dates have no row for, generated for
/// its type as the Generate button generates them, in date order.
List<ItineraryDay> withMissingDays(List<ItineraryDay> days, Trip working) {
  final covered = {for (final d in days) tripDay(d.date)};
  final missing = ItineraryDay.generateForTrip(
    tripId: working.id,
    startDate: working.startDate,
    endDate: working.endDate,
    tripType: working.tripType,
  ).where((d) => !covered.contains(tripDay(d.date)));
  return [...days, ...missing]..sort((a, b) => a.date.compareTo(b.date));
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
