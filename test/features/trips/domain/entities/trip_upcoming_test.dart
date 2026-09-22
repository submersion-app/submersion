import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// [days] calendar days from [day], which is not the same as adding a
/// `Duration`. A `Duration` is elapsed time, so a window that crosses a
/// daylight-saving change lands an hour short and loses a whole calendar
/// day: 24 days on from a local midnight becomes 23:00 on day 23, and
/// `daysUntilStart` -- which counts calendar days, correctly -- then
/// answers 23 rather than 24.
///
/// The difference only shows in a zone that observes the transition, so
/// this file is listed in the Timezone Tests CI job; the runners are UTC,
/// where reverting this helper would change nothing and pass.
DateTime _daysFrom(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

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
      final t = _trip(start: _daysFrom(today, 10), end: _daysFrom(today, 17));
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending today is still upcoming (date-only comparison)', () {
      // End set to 00:00 today: must count as upcoming even though the
      // instant is in the past — comparison is by calendar date.
      final t = _trip(start: _daysFrom(today, -5), end: today);
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending yesterday is not upcoming', () {
      final t = _trip(start: _daysFrom(today, -7), end: _daysFrom(today, -1));
      expect(t.isUpcoming, isFalse);
      expect(t.isInProgress, isFalse);
    });
  });

  group('Trip.isInProgress and daysUntilStart', () {
    test('trip started but not ended is in progress', () {
      final t = _trip(start: _daysFrom(today, -2), end: _daysFrom(today, 3));
      expect(t.isInProgress, isTrue);
      expect(t.isUpcoming, isTrue);
      expect(t.daysUntilStart, 0);
    });

    test('trip starting today is in progress with zero days until start', () {
      final t = _trip(start: today, end: _daysFrom(today, 5));
      expect(t.isInProgress, isTrue);
      expect(t.daysUntilStart, 0);
    });

    test('daysUntilStart counts calendar days for a future trip', () {
      final t = _trip(start: _daysFrom(today, 24), end: _daysFrom(today, 31));
      expect(t.daysUntilStart, 24);
      expect(t.isInProgress, isFalse);
    });
  });

  group('Trip.startsAfter', () {
    // The clock-free counterpart to isUpcoming/isInProgress: a caller sorting
    // several trips in one pass measures all of them against one instant
    // instead of each predicate re-reading DateTime.now().
    test('a trip starting tomorrow starts after today', () {
      final t = _trip(start: _daysFrom(today, 1), end: _daysFrom(today, 8));
      expect(t.startsAfter(today), isTrue);
    });

    test('a trip starting today does not start after today', () {
      // Date-only, so a start of 00:00 today is not "ahead" at 09:00 today.
      // The instant comparison this replaced said the opposite, and disagreed
      // with containsDate on the very same trip.
      final t = _trip(start: today, end: _daysFrom(today, 3));
      expect(t.startsAfter(today), isFalse);
      expect(t.containsDate(today), isTrue);
    });

    test('a trip that started yesterday does not start after today', () {
      final t = _trip(start: _daysFrom(today, -1), end: _daysFrom(today, 3));
      expect(t.startsAfter(today), isFalse);
    });

    test('the reference time of day is ignored, only its date counts', () {
      final t = _trip(start: today, end: _daysFrom(today, 3));
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

  group('daylight saving', () {
    // Pinned, so this does not quietly depend on the date the suite runs.
    // 2026-10-09 is 24 days before the US fall-back on 2026-11-01, the
    // first day on which `today.add(const Duration(days: 24))` lands on
    // 2026-11-01 23:00 instead of 2026-11-02. Green on a UTC runner either
    // way, which is why this file is on the Timezone Tests list.
    test('daysUntilStart keeps its count when the window crosses a '
        'transition (regression: the window was built from elapsed time)', () {
      final pinned = DateTime(2026, 10, 9, 12);
      withClock(Clock.fixed(pinned), () {
        final day = DateTime(pinned.year, pinned.month, pinned.day);
        final t = _trip(start: _daysFrom(day, 24), end: _daysFrom(day, 31));
        expect(t.daysUntilStart, 24);
      });
    });

    test('a trip starting tomorrow still starts after today on the day of '
        'the transition itself', () {
      // 2026-11-01 in a US zone is the fall-back day, so it runs 25 hours:
      // midnight plus 24 ELAPSED hours is 23:00 on that same calendar day,
      // and the date-only startsAfter would answer false. The day before
      // does not reproduce it -- 2026-10-31 midnight plus 24 hours is
      // exactly 2026-11-01 00:00, because the transition is at 02:00.
      final pinned = DateTime(2026, 11, 1, 12);
      withClock(Clock.fixed(pinned), () {
        final day = DateTime(pinned.year, pinned.month, pinned.day);
        final t = _trip(start: _daysFrom(day, 1), end: _daysFrom(day, 8));
        expect(t.startsAfter(day), isTrue);
      });
    });
  });
}
