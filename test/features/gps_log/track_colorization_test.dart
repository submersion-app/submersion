import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';

GpsTrackPoint p(double lat, double lon, {int t = 0}) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: lon);

void main() {
  group('uniform mode', () {
    test('produces exactly one run covering every point', () {
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.001, 0.0, t: 10),
        p(0.002, 0.0, t: 20),
      ];
      final runs = bucketizeTrack(points, TrackColorMode.uniform);
      expect(runs.length, 1);
      expect(runs.first.bucket, 0);
      expect(runs.first.points.length, 3);
    });
  });

  group('elapsed mode', () {
    test('assigns increasing buckets across the track', () {
      final points = List.generate(9, (i) => p(0.0, i * 0.001, t: i * 100));
      final runs = bucketizeTrack(points, TrackColorMode.elapsed, buckets: 3);
      expect(runs.length, greaterThan(1));
      expect(runs.first.bucket, lessThan(runs.last.bucket));
    });

    test('runs share a boundary point so the line has no gaps', () {
      final points = List.generate(9, (i) => p(0.0, i * 0.001, t: i * 100));
      final runs = bucketizeTrack(points, TrackColorMode.elapsed, buckets: 3);
      for (var i = 1; i < runs.length; i++) {
        expect(
          runs[i].points.first.timestamp,
          runs[i - 1].points.last.timestamp,
          reason: 'run $i must start where run ${i - 1} ended',
        );
      }
    });
  });

  group('speed mode', () {
    test('separates a slow leg from a fast leg into different buckets', () {
      // Leg 1: 0.0001 deg lat (11.1 m) over 10 s  = 1.11 m/s
      // Leg 2: 0.0100 deg lat (1112 m) over 10 s  = 111 m/s
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.0001, 0.0, t: 10),
        p(0.0101, 0.0, t: 20),
      ];
      final runs = bucketizeTrack(points, TrackColorMode.speed, buckets: 4);
      expect(runs.length, 2);
      expect(runs.first.bucket, isNot(equals(runs.last.bucket)));
    });

    test('merges consecutive legs at the same speed into one run', () {
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.001, 0.0, t: 10),
        p(0.002, 0.0, t: 20),
        p(0.003, 0.0, t: 30),
      ];
      final runs = bucketizeTrack(points, TrackColorMode.speed, buckets: 4);
      expect(runs.length, 1);
      expect(runs.first.points.length, 4);
    });
  });

  group('degenerate input', () {
    test('returns empty for an empty track', () {
      expect(bucketizeTrack(const [], TrackColorMode.speed), isEmpty);
    });

    test('returns empty for a single point (nothing to draw)', () {
      expect(bucketizeTrack([p(1, 1)], TrackColorMode.speed), isEmpty);
    });

    test('handles a two-point track as one run', () {
      final runs = bucketizeTrack([
        p(0.0, 0.0, t: 0),
        p(0.001, 0.0, t: 10),
      ], TrackColorMode.speed);
      expect(runs.length, 1);
      expect(runs.first.points.length, 2);
    });
  });

  group('speedRange', () {
    test('returns null when there are no legs', () {
      expect(speedRange(const []), isNull);
      expect(speedRange([p(1, 1)]), isNull);
    });

    test('reports min and max leg speed', () {
      final points = [
        p(0.0, 0.0, t: 0),
        p(0.0001, 0.0, t: 10),
        p(0.0101, 0.0, t: 20),
      ];
      final range = speedRange(points);
      expect(range!.min, closeTo(1.11, 0.05));
      expect(range.max, closeTo(111.2, 1.0));
    });
  });
}
