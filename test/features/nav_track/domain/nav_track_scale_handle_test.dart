import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_scale_handle.dart';

NavTrackPoint _p(double north, double east) =>
    NavTrackPoint(timestamp: 0, north: north, east: east, depth: 5);

void main() {
  group('scaleHandleIndex', () {
    test('picks the farthest sample from the first active sample', () {
      final points = [_p(0, 0), _p(30, 0), _p(30, 40), _p(10, 10)];
      expect(scaleHandleIndex(points, start: 0, end: 3), 2);
    });

    test('measures from start, not the origin or sample 0', () {
      final points = [_p(0, 0), _p(100, 100), _p(90, 90), _p(100, 120)];
      // From the origin the last sample is farthest by far; from start (index
      // 1) it is only 20 m away, and index 2 is only 14 m.
      expect(scaleHandleIndex(points, start: 1, end: 3), 3);
      final others = [_p(0, 0), _p(100, 100), _p(60, 60), _p(100, 120)];
      expect(scaleHandleIndex(others, start: 1, end: 3), 2);
    });

    test('ignores samples outside the range', () {
      final points = [_p(500, 0), _p(0, 0), _p(20, 0), _p(30, 0), _p(900, 0)];
      expect(scaleHandleIndex(points, start: 1, end: 3), 3);
    });

    test('is null below 10 m', () {
      expect(scaleHandleIndex([_p(0, 0), _p(9.99, 0)], start: 0, end: 1), null);
    });

    test('is non-null at exactly 10 m', () {
      expect(scaleHandleIndex([_p(0, 0), _p(10, 0)], start: 0, end: 1), 1);
    });

    test('the first of equal samples wins', () {
      final points = [_p(0, 0), _p(20, 0), _p(0, 20)];
      expect(scaleHandleIndex(points, start: 0, end: 2), 1);
    });

    test('is null with no points', () {
      expect(scaleHandleIndex(const [], start: 0, end: 0), null);
    });
  });

  group('scaleFromDrag', () {
    test('grows by the ratio of distances', () {
      expect(
        scaleFromDrag(pressScale: 1, pressDistance: 100, currentDistance: 138),
        closeTo(1.38, 1e-9),
      );
    });

    test('works from the scale held at the press', () {
      expect(
        scaleFromDrag(
          pressScale: 1.5,
          pressDistance: 200,
          currentDistance: 100,
        ),
        closeTo(0.75, 1e-9),
      );
    });

    test('rounds to 0.1%', () {
      expect(
        scaleFromDrag(pressScale: 1, pressDistance: 3, currentDistance: 3.0101),
        1.003,
      );
    });

    test('clamps at 4.0', () {
      expect(
        scaleFromDrag(pressScale: 2, pressDistance: 10, currentDistance: 100),
        4,
      );
    });

    test('clamps at 0.25', () {
      expect(
        scaleFromDrag(pressScale: 1, pressDistance: 100, currentDistance: 1),
        0.25,
      );
    });

    test('a pointer on the pivot clamps at 0.25 and never flips', () {
      expect(
        scaleFromDrag(pressScale: 1, pressDistance: 100, currentDistance: 0),
        0.25,
      );
    });

    test('a press distance of 0 returns the press scale', () {
      expect(
        scaleFromDrag(pressScale: 1.2, pressDistance: 0, currentDistance: 50),
        1.2,
      );
    });
  });
}
