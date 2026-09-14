import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/nav_tracks/$name').readAsBytesSync();

NavTrackPoint _p({
  int timestamp = 0,
  double north = 0,
  double east = 0,
  double depth = 0,
  double? distance,
  double? speed,
  double? temperature,
}) => NavTrackPoint(
  timestamp: timestamp,
  north: north,
  east: east,
  depth: depth,
  distance: distance,
  speed: speed,
  temperature: temperature,
);

double _dist(double n1, double e1, double n2, double e2) {
  final dn = n2 - n1;
  final de = e2 - e1;
  return math.sqrt(dn * dn + de * de);
}

void main() {
  // A simple straight-line route: 5 samples, 100 m apart, heading due
  // north (constant east=0), 20 s apart, so cumulative distance and time
  // both grow uniformly and every property is easy to reason about.
  List<NavTrackPoint> straightRoute() => [
    for (var i = 0; i < 5; i++)
      _p(timestamp: i * 20, north: i * 100.0, east: 0, distance: i * 100.0),
  ];

  group('NavTrackCorrector.apply with endMode none', () {
    test('is the identity when no rotation is applied either', () {
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(),
      );
      for (var i = 0; i < points.length; i++) {
        expect(corrected[i].east, points[i].east);
        expect(corrected[i].north, points[i].north);
        expect(corrected[i].depth, points[i].depth);
        expect(corrected[i].timestamp, points[i].timestamp);
      }
    });

    test('still applies rotation even with no drift correction', () {
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(headingOffsetDeg: 90),
      );
      // A 90-degree clockwise rotation turns "due north" into "due east".
      expect(corrected.last.east, closeTo(400, 1e-6));
      expect(corrected.last.north, closeTo(0, 1e-6));
    });
  });

  group('NavTrackCorrector rotation', () {
    test('preserves distances between consecutive points', () {
      final points = straightRoute();
      final rawSteps = [
        for (var i = 1; i < points.length; i++)
          _dist(
            points[i - 1].north,
            points[i - 1].east,
            points[i].north,
            points[i].east,
          ),
      ];
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(headingOffsetDeg: 37),
      );
      final correctedSteps = [
        for (var i = 1; i < corrected.length; i++)
          _dist(
            corrected[i - 1].north,
            corrected[i - 1].east,
            corrected[i].north,
            corrected[i].east,
          ),
      ];
      for (var i = 0; i < rawSteps.length; i++) {
        expect(correctedSteps[i], closeTo(rawSteps[i], 1e-6));
      }
    });

    test('360 degrees is the identity', () {
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(headingOffsetDeg: 360),
      );
      for (var i = 0; i < points.length; i++) {
        expect(corrected[i].east, closeTo(points[i].east, 1e-6));
        expect(corrected[i].north, closeTo(points[i].north, 1e-6));
      }
    });
  });

  group('NavTrackCorrector.apply with endMode sameAsStart', () {
    test('closes the loop: the last point lands on the (rotated) start', () {
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(endMode: NavTrackEndMode.sameAsStart),
      );
      expect(corrected.last.east, closeTo(corrected.first.east, 1e-9));
      expect(corrected.last.north, closeTo(corrected.first.north, 1e-9));
    });

    test('distributes the correction proportionally to distance travelled '
        'when trust is zero (the classic rubber band)', () {
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(endMode: NavTrackEndMode.sameAsStart),
      );
      // Raw north values are 0, 100, 200, 300, 400; the residual (-400) is
      // spread proportionally to distance, so at the midpoint (index 2,
      // half the total distance) half the residual has been applied.
      expect(corrected[2].north, closeTo(200 - 200, 1e-6));
      expect(corrected[1].north, closeTo(100 - 100, 1e-6));
    });
  });

  group('NavTrackCorrector.apply with a trust fraction', () {
    test('leaves the prefix up to the trust mark bit-identical', () {
      final points = straightRoute();
      const trustAtHalf = 0.5; // trusted up to 200 m of 400 m total
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: trustAtHalf,
        ),
      );
      // Samples 0, 1, 2 sit at cumulative distance 0, 100, 200 -- at or
      // before the 200 m trust mark -- and must be untouched.
      expect(corrected[0].north, points[0].north);
      expect(corrected[1].north, points[1].north);
      expect(corrected[2].north, points[2].north);
      // Sample 4, past the trust mark, must have moved toward the target.
      expect(corrected[4].north, isNot(points[4].north));
      expect(corrected[4].north, closeTo(0, 1e-6)); // sameAsStart -> origin
    });

    test('a trust fraction of 1 leaves the whole route untouched', () {
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: 1,
        ),
      );
      for (var i = 0; i < points.length; i++) {
        expect(corrected[i].north, points[i].north);
        expect(corrected[i].east, points[i].east);
      }
    });
  });

  group('NavTrackCorrector.apply with endMode point', () {
    test('lands the route end on the map point, via the anchor', () {
      const anchor = GeoPoint(47.0, 8.0);
      final endPoint = offsetToGeoPoint(anchor, east: 30, north: 40);
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        NavTrackCorrection(
          anchor: anchor,
          endMode: NavTrackEndMode.point,
          endPoint: endPoint,
        ),
      );
      expect(corrected.last.east, closeTo(30, 1e-6));
      expect(corrected.last.north, closeTo(40, 1e-6));
    });
  });

  group('NavTrackCorrector.apply device distance vs path length', () {
    test('prefers the device distance channel when it is monotone', () {
      // Device distance is deliberately NOT proportional to the straight-
      // line path length (as if the diver looped around), so the trust
      // fraction picks a different cutoff sample depending on which
      // distance measure is used -- proving which one won.
      final points = [
        _p(timestamp: 0, north: 0, east: 0, distance: 0),
        _p(
          timestamp: 10,
          north: 100,
          east: 0,
          distance: 10,
        ), // tiny device reading
        _p(timestamp: 20, north: 200, east: 0, distance: 1000), // big jump
      ];
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: 0.5,
        ),
      );
      // Device distance: 0, 10, 1000 -> half of 1000 is 500, so sample 1
      // (distance 10) is well before the trust mark and stays untouched;
      // the path-length distance (0, 100, 200) would instead put the trust
      // mark between samples 0 and 1, corrupting sample 1.
      expect(corrected[1].north, points[1].north);
    });

    test('falls back to path length when device distance is not monotone', () {
      final points = [
        _p(timestamp: 0, north: 0, east: 0, distance: 0),
        _p(
          timestamp: 10,
          north: 100,
          east: 0,
          distance: 50,
        ), // goes backwards later
        _p(timestamp: 20, north: 200, east: 0, distance: 40), // < previous
      ];
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: 0.5,
        ),
      );
      // Path length: 0, 100, 200 -- half of 200 is 100, so sample 1 sits
      // exactly at the trust mark and stays untouched; sample 2 is fully
      // corrected onto the origin.
      expect(corrected[1].north, points[1].north);
      expect(corrected[2].north, closeTo(0, 1e-6));
    });

    test('falls back to path length when any distance reading is missing', () {
      final points = [
        _p(timestamp: 0, north: 0, east: 0, distance: 0),
        _p(timestamp: 10, north: 100, east: 0), // no distance reading
        _p(timestamp: 20, north: 200, east: 0, distance: 999),
      ];
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: 0.5,
        ),
      );
      expect(corrected[1].north, points[1].north);
    });
  });

  group('NavTrackCorrector.apply with endMode gpsFix', () {
    test(
      'lands the reckoned route on the recording\'s own GPS-fixed sample',
      () {
        final points = [
          _p(timestamp: 0, north: 0, east: 0, depth: 5, distance: 0),
          _p(timestamp: 2, north: 100, east: 0, depth: 0, distance: 100),
          // A genuine fix event: >50 m in <=5 s at the surface.
          _p(timestamp: 4, north: 500, east: 20, depth: 0, distance: 100),
        ];
        final corrected = NavTrackCorrector.apply(
          points,
          const NavTrackCorrection(endMode: NavTrackEndMode.gpsFix),
        );
        // The reckoned prefix (before the fix event) should now end exactly
        // on the fix sample's own position.
        expect(corrected[1].north, closeTo(500, 1e-6));
        expect(corrected[1].east, closeTo(20, 1e-6));
      },
    );

    test('falls back to no correction when the recording has no fix event', () {
      final points = straightRoute();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(endMode: NavTrackEndMode.gpsFix),
      );
      for (var i = 0; i < points.length; i++) {
        expect(corrected[i].north, points[i].north);
        expect(corrected[i].east, points[i].east);
      }
    });
  });

  group('NavTrackCorrector.apply on the real fixture with a GPS fix '
      '(regression: the active range must stop before the fix, not at the '
      'very last raw sample)', () {
    late List<NavTrackPoint> points;
    late int lastPreFixIndex;

    setUp(() {
      final track = parseSeacraftEncCsv(_fixture('seacraft_enc3_gps_fix.csv'));
      points = track.points;
      final kinds = NavTrackSegmenter.classify(points).kinds;
      lastPreFixIndex = kinds.lastIndexOf(NavTrackSampleKind.underwater);
      final lastSurfaceReckoned = kinds.lastIndexOf(
        NavTrackSampleKind.surfaceReckoned,
      );
      if (lastSurfaceReckoned > lastPreFixIndex) {
        lastPreFixIndex = lastSurfaceReckoned;
      }
    });

    test('sameAsStart lands the rendered end (last pre-fix sample) on the '
        'start, not just the very last raw sample', () {
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(endMode: NavTrackEndMode.sameAsStart),
      );
      // This is the sample the polyline/3D ribbon actually ends on
      // (NavTrackPolylineLayer.kept / NavTrackPathAdapter both stop
      // here); it must land close to the (rotated) start, not sit
      // wherever the old full-length denominator happened to leave it.
      final startEast = corrected.first.east;
      final startNorth = corrected.first.north;
      final endEast = corrected[lastPreFixIndex].east;
      final endNorth = corrected[lastPreFixIndex].north;
      final residual = math.sqrt(
        math.pow(endEast - startEast, 2) + math.pow(endNorth - startNorth, 2),
      );
      expect(
        residual,
        lessThan(1.0),
        reason:
            'the last rendered (pre-fix) sample should be within 1 m of '
            'the start once sameAsStart is applied; residual was '
            '$residual m',
      );
    });

    test('the trust slider visibly moves the pre-fix (rendered) portion of '
        'the route', () {
      final corrected0 = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: 0,
        ),
      );
      final correctedHalf = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: 0.5,
        ),
      );
      // Compare a sample from deep in the dive (well before the surface
      // swim, where the device's own cumulative distance is still
      // actively increasing rather than frozen) between trust 0 and
      // trust 0.5: with the active range correctly stopped before the
      // fix, this sample sits clearly past the 0.5 trust mark in
      // cumulative distance and must move noticeably. Under the old bug
      // the denominator included the huge post-fix jump, so almost the
      // whole distance budget lived in the invisible post-fix segment
      // and this barely moved.
      const probe = 900;
      expect(probe, lessThan(lastPreFixIndex));
      final dEast = correctedHalf[probe].east - corrected0[probe].east;
      final dNorth = correctedHalf[probe].north - corrected0[probe].north;
      final moved = math.sqrt(dEast * dEast + dNorth * dNorth);
      expect(
        moved,
        greaterThan(1.0),
        reason:
            'moving the trust fraction from 0 to 0.5 should visibly '
            'move the pre-fix route by more than 1 m; it moved $moved m',
      );
    });
  });

  group('NavTrackCorrector.activeRangeStartIndex / activeRangeEndIndex '
      '(regression: a fix event can happen BEFORE the real dive too, not '
      'only after it)', () {
    // A pre-dive GPS re-calibration (index 0 -> 1, a >50 m jump at the
    // surface in <=5 s), then the real dive, no fix afterwards.
    List<NavTrackPoint> preDiveFixOnly() => [
      _p(timestamp: 0, north: 0, east: 0, depth: 0),
      _p(timestamp: 2, north: 300, east: 0, depth: 0), // pre-dive fix jump
      _p(timestamp: 4, north: 302, east: 1, depth: 0),
      _p(timestamp: 6, north: 302, east: 5, depth: 5), // descending
      _p(timestamp: 8, north: 305, east: 8, depth: 12),
      _p(timestamp: 10, north: 310, east: 10, depth: 20),
    ];

    // No fix event anywhere in the recording.
    List<NavTrackPoint> noFixAtAll() => straightRoute();

    // A post-dive-only fix, mirroring the existing gps_fix fixture but as a
    // small synthetic example so the scenario is self-contained here too.
    List<NavTrackPoint> postDiveFixOnly() => [
      _p(timestamp: 0, north: 0, east: 0, depth: 5),
      _p(timestamp: 20, north: 0, east: 0, depth: 10),
      _p(timestamp: 40, north: 0, east: 0, depth: 0), // surfaces
      _p(timestamp: 42, north: 300, east: 0, depth: 0), // post-dive fix jump
      _p(timestamp: 44, north: 302, east: 1, depth: 0),
    ];

    // A pre-dive fix, the real dive, then a post-dive fix.
    List<NavTrackPoint> fixBeforeAndAfter() => [
      _p(timestamp: 0, north: 0, east: 0, depth: 0),
      _p(timestamp: 2, north: 300, east: 0, depth: 0), // pre-dive fix
      _p(timestamp: 4, north: 302, east: 1, depth: 0),
      _p(timestamp: 6, north: 302, east: 5, depth: 5), // descending
      _p(timestamp: 8, north: 305, east: 8, depth: 12),
      _p(timestamp: 10, north: 305, east: 8, depth: 0), // surfaces
      _p(timestamp: 12, north: 700, east: 100, depth: 0), // post-dive fix
      _p(timestamp: 14, north: 702, east: 101, depth: 0),
    ];

    test('no fix at all: start is 0, end is the last raw sample', () {
      final points = noFixAtAll();
      expect(NavTrackCorrector.activeRangeStartIndex(points), 0);
      expect(NavTrackCorrector.activeRangeEndIndex(points), points.length - 1);
    });

    test('post-dive fix only: start is still 0, end stops before the fix '
        '(regression guard for the original fix this refines)', () {
      final points = postDiveFixOnly();
      expect(NavTrackCorrector.activeRangeStartIndex(points), 0);
      // Index 2 is the last surfaceReckoned sample before the jump to index 3.
      expect(NavTrackCorrector.activeRangeEndIndex(points), 2);
    });

    test('pre-dive fix only: start skips both the lone pre-dive surface '
        'sample AND the fix-event run itself, landing on the real dive; '
        'end runs to the last raw sample', () {
      final points = preDiveFixOnly();
      // Index 0 is the lone pre-dive surface sample, indices 1-2 are the
      // fix event's gpsFixed run; index 3 is where real diving (depth > the
      // surface threshold) begins.
      expect(NavTrackCorrector.activeRangeStartIndex(points), 3);
      expect(NavTrackCorrector.activeRangeEndIndex(points), points.length - 1);
    });

    test('fix before and after: start skips the pre-dive fix run, end stops '
        'before the post-dive fix', () {
      final points = fixBeforeAndAfter();
      // Indices 0-2 are the pre-dive surface sample and its fix-event run;
      // index 3 is where the real dive (depth > threshold) begins.
      expect(NavTrackCorrector.activeRangeStartIndex(points), 3);
      // Index 5 is the last surfaceReckoned sample before the second jump.
      expect(NavTrackCorrector.activeRangeEndIndex(points), 5);
    });
  });

  group('NavTrackCorrector.apply with a pre-dive fix (regression: the whole '
      'active range, not just its end, must exclude a pre-dive GPS '
      'calibration)', () {
    // Same shape as activeRangeStartIndex's preDiveFixOnly above, but with a
    // clean straight-line real dive so the sameAsStart target is easy to
    // reason about: real dive samples run north 0, 100, 200 with the
    // pre-dive fix sample sitting far away at north 900.
    List<NavTrackPoint> preDiveFixThenStraightDive() => [
      _p(timestamp: 0, north: 0, east: 0, depth: 0), // pre-dive, at origin
      _p(timestamp: 2, north: 900, east: 0, depth: 0), // pre-dive fix jump
      _p(timestamp: 4, north: 900, east: 0, depth: 5), // dive starts here
      _p(timestamp: 24, north: 1000, east: 0, depth: 8),
      _p(timestamp: 44, north: 1100, east: 0, depth: 3),
    ];

    test('sameAsStart lands the end on the DIVE start (index 2), not the '
        'raw recording\'s first sample (index 0, the pre-dive fix origin)', () {
      final points = preDiveFixThenStraightDive();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(endMode: NavTrackEndMode.sameAsStart),
      );
      // The dive's own start (index 2) must stay put -- it defines the
      // target -- while the last sample lands on it.
      expect(corrected[2].north, closeTo(900, 1e-6));
      expect(corrected.last.north, closeTo(corrected[2].north, 1e-6));
      expect(corrected.last.east, closeTo(corrected[2].east, 1e-6));
    });

    test('the pre-dive calibration sample itself is left untouched by the '
        'correction (it sits outside the active range entirely)', () {
      final points = preDiveFixThenStraightDive();
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(endMode: NavTrackEndMode.sameAsStart),
      );
      // Index 0 and 1 are the pre-dive samples (before the fix and the fix
      // sample itself); neither is part of the active range, so both must
      // come through as plain rotated raw values, not shifted toward the
      // sameAsStart target.
      expect(corrected[0].north, points[0].north);
      expect(corrected[1].north, points[1].north);
    });

    test('the trust fraction is measured over the dive\'s own distance, not '
        'inflated by the pre-dive jump', () {
      final points = preDiveFixThenStraightDive();
      // Dive distance: index 2 -> 3 -> 4 is 100 m then 100 m, 200 m total.
      // Trust 0.5 should freeze the first 100 m of the DIVE (index 3), not
      // be swamped by the 900 m pre-dive jump.
      final corrected = NavTrackCorrector.apply(
        points,
        const NavTrackCorrection(
          endMode: NavTrackEndMode.sameAsStart,
          trustFraction: 0.5,
        ),
      );
      expect(corrected[3].north, points[3].north);
      expect(corrected[4].north, isNot(points[4].north));
    });
  });
}
