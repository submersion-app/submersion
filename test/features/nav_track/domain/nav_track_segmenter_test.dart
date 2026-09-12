import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/nav_tracks/$name').readAsBytesSync();

int _ts(int y, int m, int d, int h, int min, int s) =>
    DateTime.utc(y, m, d, h, min, s).millisecondsSinceEpoch ~/ 1000;

NavTrackPoint _p({
  required int t,
  double north = 0,
  double east = 0,
  double depth = 0,
  double? speed,
  double? distance,
  double? temperature,
}) => NavTrackPoint(
  timestamp: t,
  north: north,
  east: east,
  depth: depth,
  distance: distance,
  speed: speed,
  temperature: temperature,
);

void main() {
  group('NavTrackSegmenter.classify on the real dive (no GPS fix)', () {
    late List<NavTrackSampleKind> kinds;

    setUp(() {
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_real.csv'));
      kinds = NavTrackSegmenter.classify(track.points).kinds;
    });

    test('finds no fix events', () {
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_real.csv'));
      expect(NavTrackSegmenter.classify(track.points).fixEvents, isEmpty);
    });

    test('classifies every sample as underwater (depth never drops to the '
        'surface threshold)', () {
      expect(kinds.every((k) => k == NavTrackSampleKind.underwater), isTrue);
    });
  });

  group(
    'NavTrackSegmenter.classify on the fixture with a GPS re-calibration jump',
    () {
      late List<NavTrackPoint> points;
      late NavTrackSegmentation result;

      setUp(() {
        final track = parseSeacraftEncCsv(
          _fixture('seacraft_enc3_gps_fix.csv'),
        );
        points = track.points;
        result = NavTrackSegmenter.classify(points);
      });

      test('finds exactly one fix event, at the 367 m jump', () {
        expect(result.fixEvents.length, 1);
        final event = result.fixEvents.single;
        expect(points[event.index].timestamp, _ts(2026, 9, 6, 18, 52, 26));
        final stepMeters = _distance(
          event.beforeNorth,
          event.beforeEast,
          event.afterNorth,
          event.afterEast,
        );
        expect(stepMeters, greaterThan(300));
        expect(stepMeters, lessThan(400));
      });

      test('classifies 1600 samples as underwater', () {
        expect(
          result.kinds.where((k) => k == NavTrackSampleKind.underwater).length,
          1600,
        );
      });

      test('classifies the samples between surfacing and the jump as '
          'surfaceReckoned', () {
        final jumpIndex = result.fixEvents.single.index;
        final lastUnderwaterIndex = result.kinds.lastIndexOf(
          NavTrackSampleKind.underwater,
        );
        for (var i = lastUnderwaterIndex + 1; i < jumpIndex; i++) {
          expect(
            result.kinds[i],
            NavTrackSampleKind.surfaceReckoned,
            reason: 'sample $i (before the jump) should be surfaceReckoned',
          );
        }
      });

      test('classifies the jump sample and everything after it as gpsFixed '
          'or outOfWater, never underwater or surfaceReckoned', () {
        final jumpIndex = result.fixEvents.single.index;
        for (var i = jumpIndex; i < points.length; i++) {
          expect(
            result.kinds[i] == NavTrackSampleKind.gpsFixed ||
                result.kinds[i] == NavTrackSampleKind.outOfWater,
            isTrue,
            reason: 'sample $i (after the jump) was ${result.kinds[i]}',
          );
        }
      });

      test('does not treat the 25 m GPS-scatter step inside the run as a '
          'second fix event', () {
        // A genuine ~25 m step exists at 18:52:48, well inside the fixed
        // run started by the 367 m jump at 18:52:26. It must not appear as
        // its own event, and the run must stay classified as gpsFixed (or
        // outOfWater) straight through it.
        final scatterIndex = points.indexWhere(
          (p) => p.timestamp == _ts(2026, 9, 6, 18, 52, 48),
        );
        expect(scatterIndex, greaterThan(0));
        expect(result.fixEvents.length, 1);
        expect(
          result.kinds[scatterIndex] == NavTrackSampleKind.gpsFixed ||
              result.kinds[scatterIndex] == NavTrackSampleKind.outOfWater,
          isTrue,
        );
      });
    },
  );

  group('NavTrackSegmenter.classify on synthetic samples', () {
    test('a large step at real diving depth is never a fix event', () {
      // A 60 m step in one 2-second tick, but at 40 m depth: a corrupt or
      // noisy sample, not a surface GPS re-calibration. The depth gate
      // alone must suppress it.
      final points = [
        _p(t: 0, north: 0, east: 0, depth: 40),
        _p(t: 2, north: 60, east: 0, depth: 40),
        _p(t: 4, north: 60, east: 0, depth: 40),
      ];
      final result = NavTrackSegmenter.classify(points);
      expect(result.fixEvents, isEmpty);
      expect(result.kinds, everyElement(NavTrackSampleKind.underwater));
    });

    test(
      'a large surface step over more than 5 seconds is not a fix event',
      () {
        final points = [
          _p(t: 0, north: 0, east: 0, depth: 0),
          _p(t: 10, north: 200, east: 0, depth: 0),
        ];
        final result = NavTrackSegmenter.classify(points);
        expect(result.fixEvents, isEmpty);
      },
    );

    test('a large surface step at plausible swimming speed is not a fix '
        'event', () {
      final points = [
        _p(t: 0, north: 0, east: 0, depth: 0, speed: 0.3),
        // 60 m in 3 s at up to ~1.2 m/s average is still within a fast
        // scooter surface run, so the speed gate must suppress this.
        _p(t: 3, north: 60, east: 0, depth: 0, speed: 1.05),
      ];
      final result = NavTrackSegmenter.classify(points);
      expect(result.fixEvents, isEmpty);
    });

    test('a genuine surface jump with no speed reading is still detected', () {
      final points = [
        _p(t: 0, north: 0, east: 0, depth: 0),
        _p(t: 2, north: 200, east: 0, depth: 0),
      ];
      final result = NavTrackSegmenter.classify(points);
      expect(result.fixEvents.length, 1);
    });

    test('a jump right at the start, before the diver ever descends, is a fix '
        'event like any other (item 3: no existing fixture shows this, but '
        'the segmenter must already support it generically)', () {
      final points = [
        _p(t: 0, north: 0, east: 0, depth: 0), // at the surface, pre-dive
        // A genuine pre-dive GPS re-calibration, before the first
        // underwater sample.
        _p(t: 2, north: 300, east: 0, depth: 0),
        _p(t: 4, north: 302, east: 1, depth: 0),
        _p(t: 6, north: 302, east: 5, depth: 5), // now descending
        _p(t: 8, north: 305, east: 8, depth: 12),
      ];
      final result = NavTrackSegmenter.classify(points);
      expect(result.fixEvents.length, 1);
      final event = result.fixEvents.single;
      expect(event.index, 1);
      final firstUnderwaterIndex = result.kinds.indexOf(
        NavTrackSampleKind.underwater,
      );
      // The whole point of a "pre-dive" fix: it happens strictly before
      // the diver is ever classified as underwater.
      expect(firstUnderwaterIndex, greaterThan(event.index));
    });

    test('leaving the water and re-descending starts a fresh underwater run '
        'after the fixed run ends', () {
      final points = [
        _p(t: 0, north: 0, east: 0, depth: 5),
        _p(t: 2, north: 0, east: 0, depth: 0), // surfaces
        _p(t: 4, north: 200, east: 0, depth: 0), // fix event
        _p(t: 6, north: 200, east: 0, depth: 0), // still fixed
        _p(t: 8, north: 200, east: 0, depth: 5), // redescends
      ];
      final result = NavTrackSegmenter.classify(points);
      expect(result.fixEvents.length, 1);
      expect(result.kinds, [
        NavTrackSampleKind.underwater,
        NavTrackSampleKind.surfaceReckoned,
        NavTrackSampleKind.gpsFixed,
        NavTrackSampleKind.gpsFixed,
        NavTrackSampleKind.underwater,
      ]);
    });

    test('flags samples as outOfWater once distance has frozen and '
        'temperature has drifted the same way for over a minute', () {
      final points = [
        _p(t: 0, north: 0, east: 0, depth: 0, distance: 500, temperature: 20),
        _p(
          t: 2,
          north: 300,
          east: 0,
          depth: 0,
          distance: 500,
          temperature: 20,
        ), // fix event, distance already frozen at the jump
        for (var s = 10; s <= 90; s += 10)
          _p(
            t: 2 + s,
            north: 300,
            east: 0,
            depth: 0,
            distance: 500, // still frozen
            temperature: 20 + s / 30, // drifts steadily upward
          ),
      ];
      final result = NavTrackSegmenter.classify(points);
      expect(result.fixEvents.length, 1);
      // Before 60 s of continuous drift has elapsed, samples stay gpsFixed.
      expect(result.kinds[1], NavTrackSampleKind.gpsFixed);
      expect(result.kinds[2], NavTrackSampleKind.gpsFixed); // t=12s
      // Once 60+ seconds of frozen distance and one-directional drift have
      // elapsed, the run is reclassified as out of the water.
      expect(result.kinds.last, NavTrackSampleKind.outOfWater);
    });

    test('does not flag outOfWater when distance keeps increasing (still '
        'moving, not actually out of the water)', () {
      final points = [
        _p(t: 0, north: 0, east: 0, depth: 0, distance: 500, temperature: 20),
        _p(t: 2, north: 300, east: 0, depth: 0, distance: 500, temperature: 20),
        for (var s = 10; s <= 90; s += 10)
          _p(
            t: 2 + s,
            north: 300,
            east: 0,
            depth: 0,
            distance: 500 + s.toDouble(), // still advancing
            temperature: 20 + s / 30,
          ),
      ];
      final result = NavTrackSegmenter.classify(points);
      expect(result.kinds.last, NavTrackSampleKind.gpsFixed);
    });
  });

  group('NavTrackSegmenter.stabilizedFixPosition on the real fixture', () {
    late List<NavTrackPoint> points;
    late NavTrackFixEvent event;

    setUp(() {
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_gps_fix.csv'));
      points = track.points;
      event = NavTrackSegmenter.classify(points).fixEvents.single;
    });

    test('differs from the naive first-sample target and is a more central '
        'estimate of where the console actually settled', () {
      // Ground truth read directly from the fixture: the sample right
      // after the 367 m jump (18:52:26).
      final naive = points[event.index];
      expect(naive.north, closeTo(-271.850342, 1e-6));
      expect(naive.east, closeTo(204.216934, 1e-6));

      final stabilized = NavTrackSegmenter.stabilizedFixPosition(points, event);

      // Computed by running the (forward-anchored) function against the
      // fixture: the earliest run of at least 3 consecutive samples that
      // stays within 10 m of itself lands here, well before the very end
      // of the 17-minute post-fix wobble.
      expect(stabilized.north, closeTo(-268.77, 0.5));
      expect(stabilized.east, closeTo(205.99, 0.5));

      final residual = _distance(
        naive.north,
        naive.east,
        stabilized.north,
        stabilized.east,
      );
      // The naive first sample and the stabilized centroid are genuinely
      // different points (well over 2 m apart), not a rounding difference.
      expect(residual, greaterThan(2));
    });
  });

  group('NavTrackSegmenter.stabilizedFixPosition when the diver walks around '
      'on land afterwards', () {
    test('commits to the earliest stable cluster, not a later one where '
        'the diver happens to stop walking', () {
      // A fix event, then a stable cluster right after it (the real
      // exit point), then a walk (steadily changing position, so no
      // sub-window of it is stable), then a second stable cluster far
      // away (e.g. the diver has reached the car and stands still).
      // stabilizedFixPosition must report the first cluster: a
      // backward scan from the run's end would find the second one
      // instead, which is not where the diver came out of the water.
      final points = <NavTrackPoint>[
        _p(t: 0, north: 0, east: 0, depth: 5), // underwater
        _p(t: 2, north: 0, east: 0, depth: 0), // surfaces
        _p(t: 4, north: 500, east: 500, depth: 0), // the fix jump
        // Stable cluster right after the jump: the true exit point.
        _p(t: 6, north: 501, east: 500, depth: 0),
        _p(t: 8, north: 500, east: 501, depth: 0),
        _p(t: 10, north: 501, east: 501, depth: 0),
        _p(t: 12, north: 500, east: 500, depth: 0),
        // A walk: position changes steadily by more than the
        // stabilization radius each step, so no window here is stable.
        _p(t: 14, north: 530, east: 500, depth: 0),
        _p(t: 16, north: 560, east: 500, depth: 0),
        _p(t: 18, north: 590, east: 500, depth: 0),
        _p(t: 20, north: 620, east: 500, depth: 0),
        // A second stable cluster, far from the exit point (the car).
        _p(t: 22, north: 650, east: 500, depth: 0),
        _p(t: 24, north: 651, east: 500, depth: 0),
        _p(t: 26, north: 650, east: 501, depth: 0),
        _p(t: 28, north: 651, east: 501, depth: 0),
      ];
      final event = NavTrackSegmenter.classify(points).fixEvents.single;

      final stabilized = NavTrackSegmenter.stabilizedFixPosition(points, event);

      // Close to the first cluster (~500.5, 500.5), nowhere near the
      // second one (~650.5, 500.5).
      expect(stabilized.north, closeTo(500.5, 5));
      expect(stabilized.east, closeTo(500.5, 5));
    });
  });
}

double _distance(double n1, double e1, double n2, double e2) {
  final dn = n2 - n1;
  final de = e2 - e1;
  return math.sqrt(dn * dn + de * de);
}
