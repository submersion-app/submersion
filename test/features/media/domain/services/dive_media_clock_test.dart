import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/services/dive_media_clock.dart';

void main() {
  group('DiveMediaClock.start', () {
    test('is the dive start when the dive has no primary source', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: null,
      );

      expect(clock.start, DateTime.utc(2026, 5, 6, 9, 4));
    });

    // Issue #4539: a log file gave the dive 09:04:00 while the computer whose
    // samples the profile holds began at 09:04:39. Measured from 09:04:00,
    // every photo on the dive landed 39 seconds late.
    test('takes the seconds a whole-minute dive start lost', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: DateTime.utc(2026, 5, 6, 9, 4, 39),
      );

      expect(clock.start, DateTime.utc(2026, 5, 6, 9, 4, 39));
    });

    test('follows a start rounded up to the next minute', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 5),
        primarySourceEntry: DateTime.utc(2026, 5, 6, 9, 4, 39),
      );

      expect(clock.start, DateTime.utc(2026, 5, 6, 9, 4, 39));
    });

    // The diver moved the dive an hour to correct the computer's clock. The
    // dive's hour and minute are the corrected ones; only its seconds are
    // missing.
    test('keeps the hour and minute of a dive moved off its computer', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2025, 11, 13, 8, 23),
        primarySourceEntry: DateTime.utc(2025, 11, 13, 7, 23, 58),
      );

      expect(clock.start, DateTime.utc(2025, 11, 13, 8, 23, 58));
    });

    test('leaves a dive start that already has seconds alone', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4, 20),
        primarySourceEntry: DateTime.utc(2026, 5, 6, 9, 4, 39),
      );

      expect(clock.start, DateTime.utc(2026, 5, 6, 9, 4, 20));
    });

    test('reads a source entry that is not flagged UTC by its instant', () {
      final entry = DateTime.utc(2026, 5, 6, 9, 4, 39).toLocal();
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: entry,
      );

      expect(clock.start, DateTime.utc(2026, 5, 6, 9, 4, 39));
      expect(clock.start.isUtc, isTrue);
    });
  });

  group('DiveMediaClock.onDiveClock', () {
    test('returns the capture time when the dive has no shift', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: null,
      );

      expect(
        clock.onDiveClock(DateTime.utc(2026, 5, 6, 9, 9, 31)),
        DateTime.utc(2026, 5, 6, 9, 9, 31),
      );
    });

    // A camera running 47 seconds ahead of the dive computer stamps a shot
    // 47 seconds late; a shift of -47 puts it back.
    test('moves the capture time by the dive shift', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: null,
        offsetSeconds: -47,
      );

      expect(
        clock.onDiveClock(DateTime.utc(2026, 5, 6, 9, 9, 31)),
        DateTime.utc(2026, 5, 6, 9, 8, 44),
      );
    });
  });
}
