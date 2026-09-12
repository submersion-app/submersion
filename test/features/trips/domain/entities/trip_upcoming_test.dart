import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

Trip _trip({required DateTime start, required DateTime end}) => Trip(
  id: 't1',
  name: 'Test',
  startDate: start,
  endDate: end,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('Trip.isUpcoming', () {
    test('trip ending in the future is upcoming', () {
      final t = _trip(
        start: today.add(const Duration(days: 10)),
        end: today.add(const Duration(days: 17)),
      );
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending today is still upcoming (date-only comparison)', () {
      // End set to 00:00 today: must count as upcoming even though the
      // instant is in the past — comparison is by calendar date.
      final t = _trip(
        start: today.subtract(const Duration(days: 5)),
        end: today,
      );
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending yesterday is not upcoming', () {
      final t = _trip(
        start: today.subtract(const Duration(days: 7)),
        end: today.subtract(const Duration(days: 1)),
      );
      expect(t.isUpcoming, isFalse);
      expect(t.isInProgress, isFalse);
    });
  });

  group('Trip.isInProgress and daysUntilStart', () {
    test('trip started but not ended is in progress', () {
      final t = _trip(
        start: today.subtract(const Duration(days: 2)),
        end: today.add(const Duration(days: 3)),
      );
      expect(t.isInProgress, isTrue);
      expect(t.isUpcoming, isTrue);
      expect(t.daysUntilStart, 0);
    });

    test('trip starting today is in progress with zero days until start', () {
      final t = _trip(start: today, end: today.add(const Duration(days: 5)));
      expect(t.isInProgress, isTrue);
      expect(t.daysUntilStart, 0);
    });

    test('daysUntilStart counts calendar days for a future trip', () {
      final t = _trip(
        start: today.add(const Duration(days: 24)),
        end: today.add(const Duration(days: 31)),
      );
      expect(t.daysUntilStart, 24);
      expect(t.isInProgress, isFalse);
    });
  });

  group('Trip.startsAfter', () {
    // The clock-free counterpart to isUpcoming/isInProgress: a caller sorting
    // several trips in one pass measures all of them against one instant
    // instead of each predicate re-reading DateTime.now().
    test('a trip starting tomorrow starts after today', () {
      final t = _trip(
        start: today.add(const Duration(days: 1)),
        end: today.add(const Duration(days: 8)),
      );
      expect(t.startsAfter(today), isTrue);
    });

    test('a trip starting today does not start after today', () {
      // Date-only, so a start of 00:00 today is not "ahead" at 09:00 today.
      // The instant comparison this replaced said the opposite, and disagreed
      // with containsDate on the very same trip.
      final t = _trip(start: today, end: today.add(const Duration(days: 3)));
      expect(t.startsAfter(today), isFalse);
      expect(t.containsDate(today), isTrue);
    });

    test('a trip that started yesterday does not start after today', () {
      final t = _trip(
        start: today.subtract(const Duration(days: 1)),
        end: today.add(const Duration(days: 3)),
      );
      expect(t.startsAfter(today), isFalse);
    });

    test('the reference time of day is ignored, only its date counts', () {
      final t = _trip(start: today, end: today.add(const Duration(days: 3)));
      expect(t.startsAfter(today.add(const Duration(hours: 23))), isFalse);
      expect(
        t.startsAfter(today.subtract(const Duration(hours: 1))),
        isTrue,
        reason: 'an hour before midnight is the previous calendar day',
      );
    });
  });

  group('Trip.endsBefore', () {
    // One reference date for "is this trip over": the scrubber card
    // combined two getters that each read the clock, which could
    // straddle midnight.
    final trip = Trip(
      id: 't',
      name: 'T',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 5, 18),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('a trip is over from the day after its last day', () {
      expect(trip.endsBefore(DateTime(2026, 6, 6)), isTrue);
      expect(trip.endsBefore(DateTime(2026, 6, 6, 0, 1)), isTrue);
    });

    test('its last day, at any hour, is not after it', () {
      expect(trip.endsBefore(DateTime(2026, 6, 5)), isFalse);
      expect(trip.endsBefore(DateTime(2026, 6, 5, 23, 59)), isFalse);
      expect(trip.endsBefore(DateTime(2026, 6, 1)), isFalse);
    });
  });
}
