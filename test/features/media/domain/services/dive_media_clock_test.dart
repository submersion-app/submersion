import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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

  group('DiveMediaClock.isValidOffset', () {
    test('holds a camera a decade out, either way', () {
      const decade = 10 * 365 * 24 * 60 * 60;

      expect(DiveMediaClock.isValidOffset(0), isTrue);
      expect(DiveMediaClock.isValidOffset(-decade), isTrue);
      expect(DiveMediaClock.isValidOffset(decade), isTrue);
      expect(
        DiveMediaClock.isValidOffset(DiveMediaClock.maxOffsetSeconds),
        isTrue,
      );
    });

    test('refuses anything past a century', () {
      expect(
        DiveMediaClock.isValidOffset(DiveMediaClock.maxOffsetSeconds + 1),
        isFalse,
      );
      expect(
        DiveMediaClock.isValidOffset(-DiveMediaClock.maxOffsetSeconds - 1),
        isFalse,
      );
      // The smallest integer is its own magnitude, so a check by size alone
      // would let it through.
      expect(DiveMediaClock.isValidOffset(-9223372036854775808), isFalse);
    });
  });

  group('DiveMediaClock.countsFrom', () {
    test('is the start when the dive has no shift', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: null,
      );

      expect(clock.countsFrom, DateTime.utc(2026, 5, 6, 9, 4));
    });

    // A camera running 47 seconds ahead of the dive computer stamps a shot
    // 47 seconds late, so its times count from 47 seconds after the start.
    test('moves the other way by the dive shift', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: null,
        offsetSeconds: -47,
      );

      expect(clock.countsFrom, DateTime.utc(2026, 5, 6, 9, 4, 47));
      expect(
        DateTime.utc(2026, 5, 6, 9, 9, 31).difference(clock.countsFrom),
        const Duration(minutes: 4, seconds: 44),
      );
    });

    // A shift past the bound is a damaged row; counting from it would
    // overflow, so the dive's media is placed unshifted.
    test('ignores a shift a dive cannot hold', () {
      final clock = DiveMediaClock.of(
        diveStart: DateTime.utc(2026, 5, 6, 9, 4),
        primarySourceEntry: null,
        offsetSeconds: 9000000000000000000,
      );

      expect(clock.offsetSeconds, 0);
      expect(clock.countsFrom, DateTime.utc(2026, 5, 6, 9, 4));
    });
  });

  // A capture time is matched to a dive on the clock it is later placed by.
  group('DiveMediaClock.onCameraClock', () {
    Dive dive(int shift) => Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 5, 6, 9, 4),
      mediaTimeOffsetSeconds: shift,
    );

    test('is the dive time itself with no shift', () {
      expect(
        DiveMediaClock.onCameraClock(dive(0), DateTime.utc(2026, 5, 6, 9, 4)),
        DateTime.utc(2026, 5, 6, 9, 4),
      );
    });

    // A camera six hours ahead stamps the 09:04 entry as 15:04.
    test('reads later on a camera running ahead', () {
      expect(
        DiveMediaClock.onCameraClock(
          dive(-21600),
          DateTime.utc(2026, 5, 6, 9, 4),
        ),
        DateTime.utc(2026, 5, 6, 15, 4),
      );
    });

    test('reads earlier on a camera running behind', () {
      expect(
        DiveMediaClock.onCameraClock(dive(90), DateTime.utc(2026, 5, 6, 9, 4)),
        DateTime.utc(2026, 5, 6, 9, 2, 30),
      );
    });

    test('ignores a shift a dive cannot hold', () {
      expect(
        DiveMediaClock.onCameraClock(
          dive(9000000000000000000),
          DateTime.utc(2026, 5, 6, 9, 4),
        ),
        DateTime.utc(2026, 5, 6, 9, 4),
      );
    });
  });

  group('DiveMediaClock.forDive', () {
    test("reads the dive's start and shift", () {
      final clock = DiveMediaClock.forDive(
        Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 5, 6, 9),
          entryTime: DateTime.utc(2026, 5, 6, 9, 4),
          mediaTimeOffsetSeconds: -47,
        ),
        primarySourceEntry: DateTime.utc(2026, 5, 6, 9, 4, 39),
      );

      expect(clock.start, DateTime.utc(2026, 5, 6, 9, 4, 39));
      expect(clock.offsetSeconds, -47);
    });
  });
}
