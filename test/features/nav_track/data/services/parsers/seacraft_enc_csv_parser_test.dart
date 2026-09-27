import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/nav_tracks/$name').readAsBytesSync();

Uint8List _csv(String text) => Uint8List.fromList(utf8.encode(text));

const _header =
    'Date,Time,Pos3Dx,Pos3Dy,Pos3Dz,Course,Pitch,Roll,'
    'Distance,Speed,Temp,BattV';

void main() {
  group('parseSeacraftEncCsv on the real dive (no GPS fix)', () {
    late ParsedNavTrack track;

    setUp(() {
      track = parseSeacraftEncCsv(_fixture('seacraft_enc3_real.csv'));
    });

    test('parses every data row', () {
      expect(track.points.length, 1160);
    });

    test('parses the first sample', () {
      final p = track.points.first;
      expect(
        p.timestamp,
        DateTime.utc(2026, 8, 22, 10, 10, 23).millisecondsSinceEpoch ~/ 1000,
      );
      expect(p.north, 0);
      expect(p.east, 0);
      expect(p.depth, closeTo(1.7, 1e-9));
      expect(p.course, closeTo(240.4, 1e-9));
      expect(p.pitch, closeTo(2.6, 1e-9));
      expect(p.roll, closeTo(8.5, 1e-9));
      expect(p.distance, closeTo(0.13, 1e-9));
      expect(p.speed, closeTo(10.9 / 60, 1e-9));
      expect(p.temperature, closeTo(23.7, 1e-9));
      expect(p.batteryVolts, closeTo(3.88, 1e-9));
    });

    test('parses the last sample', () {
      final p = track.points.last;
      expect(
        p.timestamp,
        DateTime.utc(2026, 8, 22, 11, 5, 47).millisecondsSinceEpoch ~/ 1000,
      );
      expect(p.north, closeTo(29.056992, 1e-6));
      expect(p.east, closeTo(110.085144, 1e-6));
      expect(p.depth, closeTo(1.1, 1e-9));
      expect(p.distance, closeTo(1093.41, 1e-9));
      expect(p.speed, closeTo(28.3 / 60, 1e-9));
    });

    test('converts Speed from m/min to m/s', () {
      // Every speed value must be positive and well under a scooter's top
      // speed once converted; catches an accidental unit passthrough.
      for (final p in track.points) {
        if (p.speed != null) {
          expect(p.speed! >= 0, isTrue);
          expect(p.speed! < 2.0, isTrue); // 120 m/min is a fast DPV
        }
      }
    });

    test('never rejects the file for exceeding the plausible-depth bench '
        'case (that is a different fixture, not this one)', () {
      expect(track.points.every((p) => p.depth <= 40), isTrue);
    });

    test('the heading recovered from consecutive north/east deltas agrees '
        'with Course under x = north, y = east, not the swapped hypothesis '
        '(pins the parser\'s NED mapping -- ground truth for item 1\'s '
        'mirrored-route investigation, design spec "Ground truth: the '
        'Seacraft ENC3 CSV")', () {
      double bearingOf(double dNorth, double dEast) =>
          (math.atan2(dEast, dNorth) * 180.0 / math.pi + 360.0) % 360.0;
      double angularDiff(double a, double b) {
        final d = (a - b).abs() % 360.0;
        return d > 180.0 ? 360.0 - d : d;
      }

      final normalErrors = <double>[];
      final swappedErrors = <double>[];
      for (var i = 1; i < track.points.length; i++) {
        final NavTrackPoint prev = track.points[i - 1];
        final NavTrackPoint cur = track.points[i];
        final course = cur.course;
        if (course == null) continue;
        final dNorth = cur.north - prev.north;
        final dEast = cur.east - prev.east;
        if (math.sqrt(dNorth * dNorth + dEast * dEast) <= 1.0) continue;
        normalErrors.add(angularDiff(bearingOf(dNorth, dEast), course));
        // The swapped hypothesis: x = east, y = north.
        swappedErrors.add(angularDiff(bearingOf(dEast, dNorth), course));
      }

      expect(normalErrors, isNotEmpty);
      final meanNormal =
          normalErrors.reduce((a, b) => a + b) / normalErrors.length;
      final meanSwapped =
          swappedErrors.reduce((a, b) => a + b) / swappedErrors.length;

      // Design doc: MAE 4.6 degrees under x = north, y = east; 138
      // degrees under the swapped hypothesis. A generous margin around
      // the measured value keeps this a real regression guard without
      // being brittle to a rounding change elsewhere in the parser.
      expect(meanNormal, lessThan(10));
      expect(meanSwapped, greaterThan(100));
      expect(meanNormal, lessThan(meanSwapped));
    });
  });

  group(
    'parseSeacraftEncCsv on the fixture with a GPS re-calibration jump',
    () {
      late ParsedNavTrack track;

      setUp(() {
        track = parseSeacraftEncCsv(_fixture('seacraft_enc3_gps_fix.csv'));
      });

      test('parses every data row', () {
        expect(track.points.length, 2155);
      });

      test('parses the first sample', () {
        final p = track.points.first;
        expect(
          p.timestamp,
          DateTime.utc(2026, 9, 6, 17, 53, 1).millisecondsSinceEpoch ~/ 1000,
        );
        expect(p.north, 0);
        expect(p.east, 0);
        expect(p.depth, closeTo(1.8, 1e-9));
        expect(p.speed, closeTo(21.7 / 60, 1e-9));
      });

      test('passes the 367 m position jump through unmodified '
          '(segmenting it is NavTrackSegmenter\'s job, not the parser\'s)', () {
        final jumpIndex = track.points.indexWhere(
          (p) =>
              p.timestamp ==
              DateTime.utc(2026, 9, 6, 18, 52, 26).millisecondsSinceEpoch ~/
                  1000,
        );
        expect(jumpIndex, greaterThan(0));
        final before = track.points[jumpIndex - 1];
        final after = track.points[jumpIndex];
        final dx = after.north - before.north;
        final dy = after.east - before.east;
        final stepMeters = (dx * dx + dy * dy);
        expect(stepMeters, greaterThan(300 * 300)); // well over the 50 m sniff
      });

      test('turns a negative BattV status code into null', () {
        final flagged = track.points.where(
          (p) =>
              p.timestamp ==
              DateTime.utc(2026, 9, 6, 18, 16, 37).millisecondsSinceEpoch ~/
                  1000,
        );
        expect(flagged, isNotEmpty);
        expect(flagged.first.batteryVolts, isNull);
      });
    },
  );

  group('parseSeacraftEncCsv on the short manufacturer sample', () {
    test('keeps duplicate timestamps rather than rejecting them', () {
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_short.csv'));
      expect(track.points.length, 10);
      expect(track.points[0].timestamp, track.points[1].timestamp);
    });

    test('turns a negative BattV status code into null on the last sample', () {
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_short.csv'));
      expect(track.points.last.batteryVolts, isNull);
    });

    test('keeps a zero BattV reading rather than nulling it', () {
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_short.csv'));
      expect(track.points.first.batteryVolts, 0);
    });
  });

  group('parseSeacraftEncCsv on the bench test recording', () {
    test('parses without rejecting an implausible depth reading', () {
      // 002 reads over 300 m "depth" at room temperature with zero
      // distance/speed: a bench test, not a real dive. The parser's job is
      // to read the file faithfully, not to judge plausibility.
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_bench.csv'));
      expect(track.points.length, 163);
      expect(track.points.any((p) => p.depth > 300), isTrue);
    });
  });

  group('parseSeacraftEncCsv error handling', () {
    test('rejects a file with fewer than two samples', () {
      const oneRow = '$_header\n15.1.2025,16:16:07,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(oneRow)),
        throwsA(
          isA<NavTrackParseException>().having(
            (e) => e.reason,
            'reason',
            NavTrackParseReason.tooShort,
          ),
        ),
      );
    });

    test('rejects a file missing a required column', () {
      const missingZ =
          'Date,Time,Pos3Dx,Pos3Dy,Course,Pitch,Roll,'
          'Distance,Speed,Temp,BattV\n'
          '15.1.2025,16:16:07,0,0,0,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(missingZ)),
        throwsA(isA<NavTrackParseException>()),
      );
    });

    test('rejects an unparseable date/time', () {
      const bad =
          '$_header\n'
          'yesterday,16:16:07,0,0,0,0,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(bad)),
        throwsA(
          isA<NavTrackParseException>().having(
            (e) => e.reason,
            'reason',
            NavTrackParseReason.badData,
          ),
        ),
      );
    });

    test('rejects an impossible calendar date instead of letting DateTime.utc '
        'silently normalize it into a different date (31.2.2026 -> March)', () {
      // The bad date is the SECOND row, and it normalizes (under the old,
      // unvalidated behavior) to a date in March 2026 -- chronologically
      // AFTER the first row -- so a naive "timestamp goes backwards" check
      // would not catch it; only validating the calendar fields themselves
      // does.
      const bad =
          '$_header\n'
          '1.1.2026,16:16:07,0,0,0,0,0,0,0,0,20,3.9\n'
          '31.2.2026,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(bad)),
        throwsA(
          isA<NavTrackParseException>()
              .having((e) => e.reason, 'reason', NavTrackParseReason.badData)
              .having((e) => e.message, 'message', contains('Row 3')),
        ),
      );
    });

    test('rejects an impossible time-of-day instead of letting DateTime.utc '
        'silently roll it over to the next day', () {
      // Same reasoning: 25:00:00 normalizes forward to the next day's
      // 01:00:00, which still sorts after the first row, so only
      // validating the time fields themselves catches it.
      const bad =
          '$_header\n'
          '15.1.2025,10:00:00,0,0,0,0,0,0,0,0,20,3.9\n'
          '15.1.2025,25:00:00,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(bad)),
        throwsA(
          isA<NavTrackParseException>()
              .having((e) => e.reason, 'reason', NavTrackParseReason.badData)
              .having((e) => e.message, 'message', contains('Row 3')),
        ),
      );
    });

    test('rejects a timestamp that goes backwards', () {
      const bad =
          '$_header\n'
          '15.1.2025,16:16:10,0,0,0,0,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:07,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(bad)),
        throwsA(
          isA<NavTrackParseException>().having(
            (e) => e.reason,
            'reason',
            NavTrackParseReason.badData,
          ),
        ),
      );
    });

    test('rejects a depth far above the surface as bad data', () {
      const bad =
          '$_header\n'
          '15.1.2025,16:16:07,0,0,-5,0,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(bad)),
        throwsA(
          isA<NavTrackParseException>().having(
            (e) => e.reason,
            'reason',
            NavTrackParseReason.badData,
          ),
        ),
      );
    });

    test('clamps a small negative depth to zero rather than rejecting it', () {
      const ok =
          '$_header\n'
          '15.1.2025,16:16:07,0,0,-0.3,0,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      final track = parseSeacraftEncCsv(_csv(ok));
      expect(track.points.first.depth, 0);
    });

    test('nulls out an out-of-range course instead of rejecting the row', () {
      const ok =
          '$_header\n'
          '15.1.2025,16:16:07,0,0,0,412,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      final track = parseSeacraftEncCsv(_csv(ok));
      expect(track.points.first.course, isNull);
    });

    test('rejects a NaN value in a required column instead of persisting '
        'a non-finite coordinate', () {
      const bad =
          '$_header\n'
          '15.1.2025,16:16:07,NaN,0,0,0,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(bad)),
        throwsA(
          isA<NavTrackParseException>().having(
            (e) => e.reason,
            'reason',
            NavTrackParseReason.badData,
          ),
        ),
      );
    });

    test('rejects an Infinity value in a required column', () {
      const bad =
          '$_header\n'
          '15.1.2025,16:16:07,0,Infinity,0,0,0,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      expect(
        () => parseSeacraftEncCsv(_csv(bad)),
        throwsA(
          isA<NavTrackParseException>().having(
            (e) => e.reason,
            'reason',
            NavTrackParseReason.badData,
          ),
        ),
      );
    });

    test('nulls out a NaN reading in an optional column instead of '
        'rejecting the row', () {
      const ok =
          '$_header\n'
          '15.1.2025,16:16:07,0,0,0,0,NaN,0,0,0,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      final track = parseSeacraftEncCsv(_csv(ok));
      expect(track.points.first.pitch, isNull);
    });

    test('nulls out an Infinity reading in an optional column instead of '
        'rejecting the row', () {
      const ok =
          '$_header\n'
          '15.1.2025,16:16:07,0,0,0,0,0,0,0,-Infinity,20,3.9\n'
          '15.1.2025,16:16:09,0,0,0,0,0,0,0,0,20,3.9\n';
      final track = parseSeacraftEncCsv(_csv(ok));
      expect(track.points.first.speed, isNull);
    });

    test('rejects an empty file', () {
      expect(
        () => parseSeacraftEncCsv(_csv('')),
        throwsA(isA<NavTrackParseException>()),
      );
    });

    test('rejects a header-only file', () {
      expect(
        () => parseSeacraftEncCsv(_csv('$_header\n')),
        throwsA(isA<NavTrackParseException>()),
      );
    });
  });
}
