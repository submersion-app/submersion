import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

void main() {
  final start = DateTime(2026, 3, 8);
  final end = DateTime(2026, 3, 14);

  ItineraryDay row(int day, DayType type) => ItineraryDay(
    id: 'i$day',
    tripId: 't1',
    dayNumber: day - 7,
    date: DateTime(2026, 3, day),
    dayType: type,
    createdAt: start,
    updatedAt: start,
  );

  test('the days between two dates, across a daylight-saving change', () {
    // 2026-03-08 is the US spring-forward: a 23-hour day.
    expect(tripDaysBetween(DateTime(2026, 3, 7, 18), DateTime(2026, 3, 9)), [
      DateTime(2026, 3, 7),
      DateTime(2026, 3, 8),
      DateTime(2026, 3, 9),
    ]);
    expect(tripDaysBetween(end, start), isEmpty);
  });

  test('with no itinerary every trip day is a dive day', () {
    expect(tripDiveDayCount(start: start, end: end, itinerary: const []), 7);
  });

  test('a day typed otherwise is not; an uncovered day still is', () {
    expect(
      tripDiveDayCount(
        start: start,
        end: end,
        itinerary: [row(9, DayType.seaDay), row(10, DayType.diveDay)],
      ),
      6,
    );
    expect(isTripDiveDay(null), isTrue);
    expect(isTripDiveDay(row(9, DayType.embark)), isFalse);
  });

  test('rows outside the trip are ignored', () {
    expect(
      tripDiveDayCount(
        start: start,
        end: end,
        itinerary: [row(20, DayType.seaDay)],
      ),
      7,
    );
  });

  group('isBarePlanDay', () {
    test('a dive day with no port, position or notes is bare', () {
      expect(isBarePlanDay(row(9, DayType.diveDay)), isTrue);
      // A planned count is the plan itself, not content.
      expect(
        isBarePlanDay(row(9, DayType.diveDay).copyWith(plannedDives: 3)),
        isTrue,
      );
      expect(
        isBarePlanDay(row(9, DayType.diveDay).copyWith(portName: '')),
        isTrue,
      );
    });

    test('any content or another day type makes it more than a plan', () {
      final bare = row(9, DayType.diveDay);
      expect(isBarePlanDay(row(9, DayType.seaDay)), isFalse);
      expect(isBarePlanDay(bare.copyWith(portName: 'Sorong')), isFalse);
      expect(isBarePlanDay(bare.copyWith(latitude: -0.9)), isFalse);
      expect(isBarePlanDay(bare.copyWith(longitude: 131.2)), isFalse);
      expect(isBarePlanDay(bare.copyWith(notes: 'Manta point')), isFalse);
    });
  });
}
