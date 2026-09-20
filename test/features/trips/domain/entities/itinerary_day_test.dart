import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

void main() {
  group('ItineraryDay', () {
    late ItineraryDay day;

    setUp(() {
      day = ItineraryDay(
        id: 'day-1',
        tripId: 'trip-1',
        dayNumber: 1,
        date: DateTime(2024, 3, 5),
        dayType: DayType.embark,
        portName: 'Hurghada Marina',
        latitude: 27.2579,
        longitude: 33.8116,
        notes: 'Board at 4pm',
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
    });

    test('props returns all fields for equality', () {
      final same = ItineraryDay(
        id: 'day-1',
        tripId: 'trip-1',
        dayNumber: 1,
        date: DateTime(2024, 3, 5),
        dayType: DayType.embark,
        portName: 'Hurghada Marina',
        latitude: 27.2579,
        longitude: 33.8116,
        notes: 'Board at 4pm',
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime(2024, 3, 1),
      );
      expect(day, equals(same));
    });

    test('copyWith preserves values when not provided', () {
      final copy = day.copyWith();
      expect(copy, equals(day));
    });

    test('copyWith updates provided values', () {
      final updated = day.copyWith(
        dayType: DayType.diveDay,
        notes: 'Updated notes',
      );
      expect(updated.dayType, DayType.diveDay);
      expect(updated.notes, 'Updated notes');
      expect(updated.portName, 'Hurghada Marina');
    });

    test('copyWith can set nullable fields to null', () {
      final cleared = day.copyWith(portName: null, latitude: null);
      expect(cleared.portName, isNull);
      expect(cleared.latitude, isNull);
    });

    test('hasCoordinates returns true when both lat/lng set', () {
      expect(day.hasCoordinates, isTrue);
    });

    test('hasCoordinates returns false when missing', () {
      final noCoords = day.copyWith(latitude: null, longitude: null);
      expect(noCoords.hasCoordinates, isFalse);
    });
  });

  group('ItineraryDay.generateForTrip', () {
    test('generates correct number of days for date range', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 12),
      );
      expect(days, hasLength(8));
    });

    test('first day is embark, last day is disembark', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 12),
      );
      expect(days.first.dayType, DayType.embark);
      expect(days.first.dayNumber, 1);
      expect(days.last.dayType, DayType.disembark);
      expect(days.last.dayNumber, 8);
    });

    test('middle days default to diveDay', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 12),
      );
      for (int i = 1; i < days.length - 1; i++) {
        expect(days[i].dayType, DayType.diveDay);
      }
    });

    test('single-day trip has embark type', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 5),
      );
      expect(days, hasLength(1));
      expect(days.first.dayType, DayType.embark);
    });

    test('two-day trip has embark and disembark', () {
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2024, 3, 5),
        endDate: DateTime(2024, 3, 6),
      );
      expect(days, hasLength(2));
      expect(days[0].dayType, DayType.embark);
      expect(days[1].dayType, DayType.disembark);
    });

    // A local calendar day is 23 hours at a spring-forward and 25 at a
    // fall-back, so elapsed-time arithmetic (`Duration.inDays`, which floors)
    // drops or invents a day for any trip spanning a transition. Both windows
    // below are pinned to explicit calendar dates: a window built from
    // `DateTime.now()` plus a `Duration` only crosses a transition for part of
    // the year, so it would leave this unguarded most of the time.
    test('counts calendar days across a fall-back DST boundary', () {
      // US DST ends 2026-11-01, making that a 25-hour local day (73 elapsed
      // hours over the window, which elapsed-time rounding must not read as 5).
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2026, 10, 30),
        endDate: DateTime(2026, 11, 2),
      );

      expect(days, hasLength(4));
      expect(days.map((d) => d.date), [
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      ]);
      expect(days.map((d) => d.dayNumber), [1, 2, 3, 4]);
      expect(days.first.dayType, DayType.embark);
      expect(days[1].dayType, DayType.diveDay);
      expect(days[2].dayType, DayType.diveDay);
      expect(days.last.dayType, DayType.disembark);
    });

    test('counts calendar days across a spring-forward DST boundary', () {
      // US DST starts 2027-03-14, making that a 23-hour local day (71 elapsed
      // hours over the window, which would floor to 3 days instead of 4).
      final days = ItineraryDay.generateForTrip(
        tripId: 'trip-1',
        startDate: DateTime(2027, 3, 12),
        endDate: DateTime(2027, 3, 15),
      );

      expect(days, hasLength(4));
      expect(days.map((d) => d.date), [
        DateTime(2027, 3, 12),
        DateTime(2027, 3, 13),
        DateTime(2027, 3, 14),
        DateTime(2027, 3, 15),
      ]);
      expect(days.map((d) => d.dayNumber), [1, 2, 3, 4]);
      expect(days.first.dayType, DayType.embark);
      expect(days[1].dayType, DayType.diveDay);
      expect(days[2].dayType, DayType.diveDay);
      expect(days.last.dayType, DayType.disembark);
    });
  });
}
