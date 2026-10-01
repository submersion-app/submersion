import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';

/// Pure. The trip's itinerary in date order, each row carrying the day
/// number the trip story gives its date.
///
/// A row's stored day number is the one the trip's start gave it when the
/// row was written, and nothing renumbers it when the start moves, by an
/// edit, a sync or an import (#2664). So the number is derived here from the
/// row's date and the story's first day ([tripStoryDaySpan]): a day kept
/// before a later start, or a trip dive before it, is day 1, as it is in the
/// story. Days are counted by calendar, so a daylight-saving change inside
/// the trip never shifts them.
///
/// Only the rows the story shows are listed ([tripStoryItinerary]): a row
/// outside the trip that carries nothing but a plan is not part of the trip
/// (#2663), and numbering it would give a day before the start day 0.
List<ItineraryDay> numberItineraryDays({
  required Trip trip,
  required List<Dive> dives,
  required List<ItineraryDay> itineraryDays,
}) {
  final (:start, end: _) = tripStoryDaySpan(
    trip: trip,
    dives: dives,
    itineraryDays: itineraryDays,
  );
  final byDate = tripStoryItinerary(trip, itineraryDays)
    ..sort((a, b) {
      final byDay = a.date.compareTo(b.date);
      return byDay != 0 ? byDay : a.id.compareTo(b.id);
    });
  return [
    for (final day in byDate)
      day.copyWith(dayNumber: calendarDaysBetween(start, day.date) + 1),
  ];
}
