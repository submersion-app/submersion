import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';

GpsTrackPoint p(int t, double lat, double lon) =>
    GpsTrackPoint(timestamp: t, latitude: lat, longitude: lon);

void main() {
  group('positionAt', () {
    test('interpolates linearly between bracketing points', () {
      final points = [p(1000, 10.0, 20.0), p(2000, 11.0, 21.0)];
      final pos = GpsTrackMatcher.positionAt(points, 1500);
      expect(pos, isNotNull);
      expect(pos!.latitude, closeTo(10.5, 1e-9));
      expect(pos.longitude, closeTo(20.5, 1e-9));
    });

    test('returns exact point on exact timestamp', () {
      final points = [p(1000, 10.0, 20.0), p(2000, 11.0, 21.0)];
      final pos = GpsTrackMatcher.positionAt(points, 2000);
      expect(pos!.latitude, 11.0);
    });

    test('clamps to first point within tolerance before track start', () {
      final points = [p(10000, 10.0, 20.0)];
      // 29 minutes before the first point: within 30-min tolerance.
      final pos = GpsTrackMatcher.positionAt(points, 10000 - 29 * 60);
      expect(pos!.latitude, 10.0);
    });

    test('returns null beyond tolerance before track start', () {
      final points = [p(10000, 10.0, 20.0)];
      final pos = GpsTrackMatcher.positionAt(points, 10000 - 31 * 60);
      expect(pos, isNull);
    });

    test('clamps to last point within tolerance after track end', () {
      final points = [p(10000, 10.0, 20.0)];
      expect(
        GpsTrackMatcher.positionAt(points, 10000 + 29 * 60)!.latitude,
        10.0,
      );
      expect(GpsTrackMatcher.positionAt(points, 10000 + 31 * 60), isNull);
    });

    test(
      'does not interpolate across an interior gap wider than 2x tolerance',
      () {
        // A 4-hour hole (recording interruption): interpolating across it
        // would place the boat mid-transit. Nearest edge within tolerance
        // wins; mid-gap has no answer.
        final points = [p(10000, 10.0, 20.0), p(10000 + 4 * 3600, 12.0, 22.0)];
        final nearStart = GpsTrackMatcher.positionAt(points, 10000 + 600);
        expect(nearStart!.latitude, 10.0);
        final midGap = GpsTrackMatcher.positionAt(points, 10000 + 2 * 3600);
        expect(midGap, isNull);
      },
    );

    test('empty points returns null', () {
      expect(GpsTrackMatcher.positionAt(const [], 1000), isNull);
    });
  });

  group('trackCovering', () {
    GpsTrack track(String id, int startMs, int endMs) =>
        GpsTrack(id: id, startTime: startMs, endTime: endMs, pointCount: 1);

    test('finds the track whose window contains the time', () {
      final tracks = [
        track('a', 1000000, 2000000),
        track('b', 5000000, 6000000),
      ];
      expect(GpsTrackMatcher.trackCovering(tracks, 5500000)!.id, 'b');
    });

    test('window extends by tolerance on both sides', () {
      final tracks = [track('a', 1000000, 2000000)];
      expect(
        GpsTrackMatcher.trackCovering(tracks, 2000000 + 29 * 60 * 1000),
        isNotNull,
      );
      expect(
        GpsTrackMatcher.trackCovering(tracks, 2000000 + 31 * 60 * 1000),
        isNull,
      );
    });

    test('skips tracks that are still recording (null endTime)', () {
      final tracks = [
        const GpsTrack(id: 'active', startTime: 1000000, pointCount: 1),
      ];
      expect(GpsTrackMatcher.trackCovering(tracks, 1500000), isNull);
    });
  });
}
