import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';

/// A trip covers its dives once the diver has touched them (issue #3351).
void main() {
  final start = DateTime(2026, 3, 5);
  final end = DateTime(2026, 3, 10);

  TripDateRange? cover(
    Iterable<DateTime> dives, {
    DateTime? from,
    DateTime? to,
  }) =>
      coveringRange(start: from ?? start, end: to ?? end, diveDateTimes: dives);

  group('coveringRange', () {
    test('already covered returns null', () {
      expect(cover([DateTime.utc(2026, 3, 7, 9)]), isNull);
    });

    test('a dive on the first and last day returns null', () {
      expect(
        cover([DateTime.utc(2026, 3, 5, 9), DateTime.utc(2026, 3, 10, 9)]),
        isNull,
      );
    });

    test('no dives returns null', () {
      expect(cover(const []), isNull);
    });

    test('an earlier dive moves only the start', () {
      final range = cover([DateTime.utc(2026, 3, 1, 9)])!;
      expect(range.start, DateTime(2026, 3, 1));
      expect(range.end, end);
    });

    test('a later dive moves only the end', () {
      final range = cover([DateTime.utc(2026, 3, 14, 9)])!;
      expect(range.start, start);
      expect(range.end, DateTime(2026, 3, 14));
    });

    test('dives on both sides move both', () {
      final range = cover([
        DateTime.utc(2026, 3, 14, 9),
        DateTime.utc(2026, 3, 1, 9),
      ])!;
      expect(range.start, DateTime(2026, 3, 1));
      expect(range.end, DateTime(2026, 3, 14));
    });

    test('a late dive stays on its wall-clock day', () {
      expect(cover([DateTime.utc(2026, 3, 10, 23, 30)]), isNull);
    });

    test('an early dive stays on its wall-clock day', () {
      expect(cover([DateTime.utc(2026, 3, 5, 0, 30)]), isNull);
    });

    test('a day across daylight saving is a calendar day', () {
      final range = cover(
        [DateTime.utc(2026, 4, 5, 8)],
        from: DateTime(2026, 3, 29),
        to: DateTime(2026, 3, 30),
      )!;
      expect(range.end, DateTime(2026, 4, 5));
    });

    test('an end stored at noon is not moved inward', () {
      expect(
        cover([DateTime.utc(2026, 3, 10, 9)], to: DateTime(2026, 3, 10, 12)),
        isNull,
      );
    });
  });

  group('ownStretch', () {
    TripDateStretch stretch(String id, {bool larger = false}) =>
        TripDateStretch(
          tripId: id,
          tripName: id,
          priorStart: start,
          priorEnd: end,
          start: start,
          end: end,
          isLargerTrip: larger,
        );

    test('skips a larger trip', () {
      expect(
        ownStretch([stretch('parent', larger: true), stretch('side')])?.tripId,
        'side',
      );
    });

    test('is null with no stretch of the dive\'s own trip', () {
      expect(ownStretch([stretch('parent', larger: true)]), isNull);
    });
  });

  group('diveSaveTouchesTrip', () {
    final day = DateTime.utc(2026, 3, 7, 9);

    test('a new dive on a trip does', () {
      expect(
        diveSaveTouchesTrip(
          tripId: 't',
          previousTripId: null,
          date: day,
          previousDate: null,
        ),
        isTrue,
      );
    });

    test('a dive with no trip does not', () {
      expect(
        diveSaveTouchesTrip(
          tripId: null,
          previousTripId: 't',
          date: day,
          previousDate: day,
        ),
        isFalse,
      );
    });

    test('the same trip and date does not', () {
      expect(
        diveSaveTouchesTrip(
          tripId: 't',
          previousTripId: 't',
          date: day,
          previousDate: day,
        ),
        isFalse,
      );
    });

    test('a later time on the same day does not', () {
      expect(
        diveSaveTouchesTrip(
          tripId: 't',
          previousTripId: 't',
          date: day.add(const Duration(hours: 3)),
          previousDate: day,
        ),
        isFalse,
      );
    });

    test('a new trip does', () {
      expect(
        diveSaveTouchesTrip(
          tripId: 't2',
          previousTripId: 't',
          date: day,
          previousDate: day,
        ),
        isTrue,
      );
    });

    test('a new day does', () {
      expect(
        diveSaveTouchesTrip(
          tripId: 't',
          previousTripId: 't',
          date: day.add(const Duration(days: 1)),
          previousDate: day,
        ),
        isTrue,
      );
    });
  });
}
