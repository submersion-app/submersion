import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_timezone_resolver.dart';

Dive _dive(DateTime entryWallClock) =>
    Dive(id: 'd', diveNumber: 1, dateTime: entryWallClock, maxDepth: 30.0);

/// Cozumel boat day: track runs 12:30-16:30 real UTC, true offset -300.
final _firstFix = DateTime.utc(2026, 5, 22, 12, 30);
final _lastFix = DateTime.utc(2026, 5, 22, 16, 30);

void main() {
  group('toWallClockEpochSecondsAt', () {
    test('is identity for a zero offset', () {
      final utc = DateTime.utc(2026, 5, 22, 13);
      expect(
        toWallClockEpochSecondsAt(utc, 0),
        utc.millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('shifts a negative offset back to local wall clock', () {
      final result = toWallClockEpochSecondsAt(
        DateTime.utc(2026, 5, 22, 13),
        -300,
      );
      final wall = DateTime.fromMillisecondsSinceEpoch(
        result * 1000,
        isUtc: true,
      );
      expect(wall.hour, 8);
      expect(wall.day, 22);
    });

    test('rolls the date backwards when the offset crosses midnight', () {
      final result = toWallClockEpochSecondsAt(
        DateTime.utc(2026, 5, 22, 2),
        -300,
      );
      final wall = DateTime.fromMillisecondsSinceEpoch(
        result * 1000,
        isUtc: true,
      );
      expect(wall.day, 21);
      expect(wall.hour, 21);
    });

    test('round-trips against the export conversion', () {
      final utc = DateTime.utc(2026, 5, 22, 13, 45, 30);
      const offset = -300;
      final wall = toWallClockEpochSecondsAt(utc, offset);
      final back = DateTime.fromMillisecondsSinceEpoch(
        wall * 1000,
        isUtc: true,
      ).subtract(const Duration(minutes: offset));
      expect(back, utc);
    });
  });

  group('offsetRangeForDive', () {
    test('bounds the offset rather than pinning it', () {
      // Dive entered at wall clock 09:15. The true offset is -300, but the
      // dive could have happened anywhere in the 4-hour track, so any offset
      // from (09:15 - 16:30) to (09:15 - 12:30) is consistent.
      final range = offsetRangeForDive(
        _dive(DateTime.utc(2026, 5, 22, 9, 15)),
        _firstFix,
        _lastFix,
      );
      expect(range!.lo, -435);
      expect(range.hi, -195);
      // The true offset is inside the range, which is all a single dive can
      // tell us. The OLD implementation returned hi (-195) as the answer -
      // offset plus the 1h45m boat ride.
      expect(-300, greaterThanOrEqualTo(range.lo));
      expect(-300, lessThanOrEqualTo(range.hi));
    });

    test('returns null when no real-world offset is consistent', () {
      // A dive 20 hours off the track implies an impossible zone.
      expect(
        offsetRangeForDive(
          _dive(DateTime.utc(2026, 5, 21, 16)),
          _firstFix,
          _lastFix,
        ),
        isNull,
      );
    });
  });

  group('resolveOffsetFromDives', () {
    test('returns null when there are no dives', () {
      expect(
        resolveOffsetFromDives(
          firstFixUtc: _firstFix,
          lastFixUtc: _lastFix,
          dives: const [],
          deviceOffsetMinutes: -300,
        ),
        isNull,
      );
    });

    test('keeps the device zone when the track permits it', () {
      // Importing on the boat: device is already in Cozumel.
      expect(
        resolveOffsetFromDives(
          firstFixUtc: _firstFix,
          lastFixUtc: _lastFix,
          dives: [_dive(DateTime.utc(2026, 5, 22, 9, 15))],
          deviceOffsetMinutes: -300,
        ),
        -300,
      );
    });

    test('pulls an impossible device zone to the nearest consistent one', () {
      // Importing at home in Berlin (+120) a track that can only be -435..-195.
      final resolved = resolveOffsetFromDives(
        firstFixUtc: _firstFix,
        lastFixUtc: _lastFix,
        dives: [_dive(DateTime.utc(2026, 5, 22, 9, 15))],
        deviceOffsetMinutes: 120,
      );
      expect(resolved, -195);
    });

    test('a two-tank day does not invent an offset from the later dive', () {
      // The old nearest-dive search ran in the conflated space and preferred
      // whichever dive's gap cancelled the offset, inferring UTC+00 for
      // Cozumel. Both dives now merely constrain, and the device prior wins.
      final resolved = resolveOffsetFromDives(
        firstFixUtc: _firstFix,
        lastFixUtc: _lastFix,
        dives: [
          _dive(DateTime.utc(2026, 5, 22, 9, 15)),
          _dive(DateTime.utc(2026, 5, 22, 12, 30)),
        ],
        deviceOffsetMinutes: -300,
      );
      expect(resolved, -300);
      expect(resolved, isNot(0));
    });

    test('ignores dives from another trip entirely', () {
      expect(
        resolveOffsetFromDives(
          firstFixUtc: _firstFix,
          lastFixUtc: _lastFix,
          dives: [_dive(DateTime.utc(2026, 8, 1, 9))],
          deviceOffsetMinutes: -300,
        ),
        isNull,
      );
    });

    test('never returns an offset outside the real-world range', () {
      final resolved = resolveOffsetFromDives(
        firstFixUtc: _firstFix,
        lastFixUtc: _lastFix,
        dives: [_dive(DateTime.utc(2026, 5, 22, 9, 15))],
        deviceOffsetMinutes: -300,
      );
      expect(resolved, greaterThanOrEqualTo(-720));
      expect(resolved, lessThanOrEqualTo(840));
    });
  });
}
