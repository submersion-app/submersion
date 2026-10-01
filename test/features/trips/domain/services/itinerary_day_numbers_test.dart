import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/itinerary_day_numbers.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';

Trip _trip(DateTime start, DateTime end) => Trip(
  id: 'trip-1',
  name: 'Red Sea',
  startDate: start,
  endDate: end,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// A row as stored: [storedNumber] is whatever the trip's start made it when
/// the row was written, which is what goes stale (#2664).
ItineraryDay _row(String id, DateTime date, {required int storedNumber}) =>
    ItineraryDay(
      id: id,
      tripId: 'trip-1',
      dayNumber: storedNumber,
      date: date,
      dayType: DayType.diveDay,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Map<String, int> _numbers(List<ItineraryDay> days) => {
  for (final d in days) d.id: d.dayNumber,
};

void main() {
  group('numberItineraryDays', () {
    test('renumbers from the start after it moves a day earlier', () {
      // Written when the trip started on the 7th: the 9th was day 3.
      final rows = [
        _row('a', DateTime(2026, 3, 7), storedNumber: 1),
        _row('b', DateTime(2026, 3, 9), storedNumber: 3),
      ];

      final numbered = numberItineraryDays(
        trip: _trip(DateTime(2026, 3, 6), DateTime(2026, 3, 10)),
        dives: const [],
        itineraryDays: rows,
      );

      expect(_numbers(numbered), {'a': 2, 'b': 4});
    });

    test('renumbers from the start after it moves later', () {
      final rows = [_row('b', DateTime(2026, 3, 9), storedNumber: 3)];

      final numbered = numberItineraryDays(
        trip: _trip(DateTime(2026, 3, 8), DateTime(2026, 3, 10)),
        dives: const [],
        itineraryDays: rows,
      );

      expect(_numbers(numbered), {'b': 2});
    });

    test('lists days by date, whatever their stored numbers say', () {
      // Two rows written under different starts: stored numbers out of order.
      final rows = [
        _row('late', DateTime(2026, 3, 10), storedNumber: 1),
        _row('early', DateTime(2026, 3, 7), storedNumber: 5),
      ];

      final numbered = numberItineraryDays(
        trip: _trip(DateTime(2026, 3, 7), DateTime(2026, 3, 10)),
        dives: const [],
        itineraryDays: rows,
      );

      expect(numbered.map((d) => d.id), ['early', 'late']);
      expect(_numbers(numbered), {'early': 1, 'late': 4});
    });

    test('a day kept before a later start is day 1, as in the story', () {
      final rows = [
        _row('kept', DateTime(2026, 3, 5), storedNumber: 1),
        _row('first', DateTime(2026, 3, 7), storedNumber: 3),
      ];

      final numbered = numberItineraryDays(
        trip: _trip(DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
        dives: const [],
        itineraryDays: rows,
      );

      expect(_numbers(numbered), {'kept': 1, 'first': 3});
    });

    test('a trip dive before the start shifts the numbers, as in the '
        'story', () {
      final rows = [_row('first', DateTime(2026, 3, 7), storedNumber: 1)];

      final numbered = numberItineraryDays(
        trip: _trip(DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
        dives: [Dive(id: 'd1', dateTime: DateTime(2026, 3, 6, 15))],
        itineraryDays: rows,
      );

      expect(_numbers(numbered), {'first': 2});
    });

    test('counts calendar days across a daylight-saving change', () {
      // 2026-03-08 is the US spring-forward day and 2026-03-29 the EU one;
      // the span crosses both.
      final rows = [_row('last', DateTime(2026, 3, 31), storedNumber: 1)];

      final numbered = numberItineraryDays(
        trip: _trip(DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
        dives: const [],
        itineraryDays: rows,
      );

      expect(_numbers(numbered), {'last': 31});
    });

    test('keeps every other field of the row', () {
      final row = _row(
        'a',
        DateTime(2026, 3, 9),
        storedNumber: 3,
      ).copyWith(portName: 'Hurghada', notes: 'Wind', plannedDives: 2);

      final numbered = numberItineraryDays(
        trip: _trip(DateTime(2026, 3, 6), DateTime(2026, 3, 10)),
        dives: const [],
        itineraryDays: [row],
      );

      expect(numbered.single, row.copyWith(dayNumber: 4));
    });

    test('agrees with the trip story day for every row', () {
      final trip = _trip(DateTime(2026, 3, 7), DateTime(2026, 3, 12));
      final dives = [Dive(id: 'd1', dateTime: DateTime(2026, 3, 13, 9))];
      final rows = [
        _row('before', DateTime(2026, 3, 4), storedNumber: 9),
        _row('mid', DateTime(2026, 3, 10), storedNumber: 1),
        _row('after', DateTime(2026, 3, 14), storedNumber: 2),
      ];

      final numbered = numberItineraryDays(
        trip: trip,
        dives: dives,
        itineraryDays: rows,
      );
      final story = buildTripStory(
        trip: trip,
        dives: dives,
        itineraryDays: rows,
        mediaByDiveId: const {},
        sightingsByDiveId: const {},
        checklistItems: const [],
        today: DateTime(2026, 6, 1),
      );

      for (final day in numbered) {
        final storyDay = story.days.singleWhere(
          (s) => s.itineraryDay?.id == day.id,
        );
        expect(day.dayNumber, storyDay.dayNumber, reason: day.id);
      }
    });

    test('an empty itinerary stays empty', () {
      expect(
        numberItineraryDays(
          trip: _trip(DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
          dives: const [],
          itineraryDays: const [],
        ),
        isEmpty,
      );
    });
  });
}
