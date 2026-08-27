import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';

GpsTrackPoint p(double lat, double lon, {int t = 0}) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: lon);

void main() {
  group('projectLocal', () {
    test('projects a degree offset at the equator to known metres', () {
      // 0.001 deg longitude at the equator = 0.001 * 111320.0 = 111.32 m
      // 0.001 deg latitude anywhere       = 0.001 * 111194.93 = 111.19 m
      final origin = p(0.0, 0.0);
      final offset = projectLocal(origin, p(0.001, 0.001));
      expect(offset.east, closeTo(111.32, 0.01));
      expect(offset.north, closeTo(111.19, 0.01));
    });

    test('is zero for the origin itself', () {
      final origin = p(20.5, -87.3);
      final offset = projectLocal(origin, origin);
      expect(offset.east, 0.0);
      expect(offset.north, 0.0);
    });

    test('takes the short way across the antimeridian', () {
      // 179.95 E to 179.95 W is 0.1 deg of boat travel, about 11 km at the
      // equator. Raw subtraction read it as -359.9 deg, roughly 40,000 km
      // WEST, which made every Douglas-Peucker deviation meaningless.
      final offset = projectLocal(p(0.0, 179.95), p(0.0, -179.95));
      expect(offset.east, closeTo(0.1 * 111320.0, 1.0));
    });

    test('unwraps in both directions', () {
      expect(unwrapLongitudeDelta(-359.9), closeTo(0.1, 1e-9));
      expect(unwrapLongitudeDelta(359.9), closeTo(-0.1, 1e-9));
      expect(unwrapLongitudeDelta(-0.1), closeTo(-0.1, 1e-9));
      expect(unwrapLongitudeDelta(0.1), closeTo(0.1, 1e-9));
      // Exactly 180 is left alone: it is equidistant either way.
      expect(unwrapLongitudeDelta(180.0), 180.0);
    });
  });

  group('simplifyTrack across the antimeridian', () {
    test('keeps a detour that a wrapped projection would have hidden', () {
      // A straight dateline run with one 500 m northward jog. Before the
      // unwrap, every point past the crossing sat ~40,000 km away in the
      // projection, so the jog's perpendicular deviation rounded to nothing
      // beside it and simplification threw the shape away.
      final points = [
        p(0.0, 179.98, t: 0),
        p(0.0, 179.99, t: 10),
        p(0.0045, -180 + 0.0, t: 20),
        p(0.0, -179.99, t: 30),
        p(0.0, -179.98, t: 40),
      ];
      final simplified = simplifyTrack(points, 100.0);
      expect(simplified.length, greaterThan(2));
      expect(
        simplified.any((q) => q.latitude > 0.004),
        isTrue,
        reason: 'the jog was simplified away',
      );
    });

    test('still collapses a genuinely straight dateline run', () {
      final points = [
        p(0.0, 179.98, t: 0),
        p(0.0, 179.99, t: 10),
        p(0.0, -180.0, t: 20),
        p(0.0, -179.99, t: 30),
        p(0.0, -179.98, t: 40),
      ];
      expect(simplifyTrack(points, 100.0).length, 2);
    });
  });

  group('simplifyTrack', () {
    test('drops a collinear midpoint', () {
      // All three on the equator: the midpoint lies exactly on the chord,
      // so its perpendicular distance is 0 and any tolerance removes it.
      final points = [p(0.0, 0.0), p(0.0, 0.001), p(0.0, 0.002)];
      final result = simplifyTrack(points, 1.0);
      expect(result.length, 2);
      expect(result.first.longitude, 0.0);
      expect(result.last.longitude, 0.002);
    });

    test('keeps a midpoint deviating more than the tolerance', () {
      // Chord runs along the equator from lon 0 to lon 0.002. The midpoint
      // sits 0.001 deg north of it = 111.19 m perpendicular deviation.
      final points = [p(0.0, 0.0), p(0.001, 0.001), p(0.0, 0.002)];
      final result = simplifyTrack(points, 50.0);
      expect(result.length, 3);
    });

    test('drops a midpoint deviating less than the tolerance', () {
      // Same 111.19 m deviation, but now under a 200 m tolerance.
      final points = [p(0.0, 0.0), p(0.001, 0.001), p(0.0, 0.002)];
      final result = simplifyTrack(points, 200.0);
      expect(result.length, 2);
    });

    test('always preserves first and last points', () {
      final points = List.generate(100, (i) => p(0.0, i * 0.00001, t: i));
      final result = simplifyTrack(points, 1000.0);
      expect(result.length, 2);
      expect(result.first.timestamp, 0);
      expect(result.last.timestamp, 99);
    });

    test('returns the input unchanged for fewer than three points', () {
      expect(simplifyTrack(const [], 10.0), isEmpty);
      expect(simplifyTrack([p(1, 1)], 10.0).length, 1);
      expect(simplifyTrack([p(1, 1), p(2, 2)], 10.0).length, 2);
    });

    test('preserves the original timestamps of surviving points', () {
      final points = [
        p(0.0, 0.0, t: 100),
        p(0.001, 0.001, t: 200),
        p(0.0, 0.002, t: 300),
      ];
      final result = simplifyTrack(points, 50.0);
      expect(result.map((e) => e.timestamp).toList(), [100, 200, 300]);
    });
  });

  group('windowTrack', () {
    final points = [
      p(0.0, 0.0, t: 100),
      p(0.0, 0.001, t: 200),
      p(0.0, 0.002, t: 300),
      p(0.0, 0.003, t: 400),
    ];

    test('includes points inside the window inclusively', () {
      final result = windowTrack(
        points,
        fromEpochSeconds: 200,
        toEpochSeconds: 300,
      );
      expect(result.map((e) => e.timestamp).toList(), [200, 300]);
    });

    test('returns everything when the window spans the track', () {
      final result = windowTrack(
        points,
        fromEpochSeconds: 0,
        toEpochSeconds: 1000,
      );
      expect(result.length, 4);
    });

    test('returns empty when the window misses the track entirely', () {
      final result = windowTrack(
        points,
        fromEpochSeconds: 500,
        toEpochSeconds: 600,
      );
      expect(result, isEmpty);
    });

    test('handles an inverted window by returning empty', () {
      final result = windowTrack(
        points,
        fromEpochSeconds: 300,
        toEpochSeconds: 200,
      );
      expect(result, isEmpty);
    });
  });

  group('trackBounds', () {
    test('returns null for an empty track', () {
      expect(trackBounds(const []), isNull);
    });

    test('computes a simple bounding box', () {
      final bounds = trackBounds([p(10.0, 20.0), p(12.0, 25.0), p(11.0, 22.0)]);
      expect(bounds!.minLat, 10.0);
      expect(bounds.maxLat, 12.0);
      expect(bounds.minLon, 20.0);
      expect(bounds.maxLon, 25.0);
    });

    test('collapses to a point for a single fix', () {
      final bounds = trackBounds([p(5.0, -3.0)]);
      expect(bounds!.minLat, 5.0);
      expect(bounds.maxLat, 5.0);
      expect(bounds.minLon, -3.0);
      expect(bounds.maxLon, -3.0);
    });

    test('normalizes an antimeridian crossing to a narrow span', () {
      // 179.9 E to 179.9 W is 0.2 deg wide, not 359.8. The unwrapped
      // maxLon exceeds 180, which is what the camera fit expects.
      final bounds = trackBounds([p(0.0, 179.9), p(0.0, -179.9)]);
      expect(bounds!.maxLon - bounds.minLon, closeTo(0.2, 1e-9));
      expect(bounds.minLon, closeTo(179.9, 1e-9));
      expect(bounds.maxLon, closeTo(180.1, 1e-9));
    });

    test(
      'does not unwrap a track that merely spans a wide longitude range',
      () {
        // A genuine 60 deg span must stay 60 deg, not get folded.
        final bounds = trackBounds([p(0.0, -30.0), p(0.0, 30.0)]);
        expect(bounds!.minLon, -30.0);
        expect(bounds.maxLon, 30.0);
      },
    );
  });

  group('speedMpsBetween', () {
    test('computes metres per second over the elapsed time', () {
      // 0.001 deg latitude = 111.19 m, over 10 s = 11.119 m/s
      final a = p(0.0, 0.0, t: 0);
      final b = p(0.001, 0.0, t: 10);
      expect(speedMpsBetween(a, b), closeTo(11.12, 0.02));
    });

    test('returns zero when no time elapsed', () {
      final a = p(0.0, 0.0, t: 50);
      final b = p(0.001, 0.0, t: 50);
      expect(speedMpsBetween(a, b), 0.0);
    });

    test(
      'returns zero for a backwards timestamp rather than a negative speed',
      () {
        final a = p(0.0, 0.0, t: 100);
        final b = p(0.001, 0.0, t: 50);
        expect(speedMpsBetween(a, b), 0.0);
      },
    );
  });

  group('trackDistanceMeters', () {
    test('sums consecutive leg distances', () {
      // Two legs of 0.001 deg latitude each = 2 * 111.19 m
      final points = [p(0.0, 0.0), p(0.001, 0.0), p(0.002, 0.0)];
      expect(trackDistanceMeters(points), closeTo(222.39, 0.1));
    });

    test('is zero for fewer than two points', () {
      expect(trackDistanceMeters(const []), 0.0);
      expect(trackDistanceMeters([p(1, 1)]), 0.0);
    });
  });
}
