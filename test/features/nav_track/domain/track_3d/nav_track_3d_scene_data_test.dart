import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';

NavTrackPoint _p({
  required int timestamp,
  double north = 0,
  double east = 0,
  double depth = 0,
  double? speed,
  double? temperature,
  double? batteryVolts,
}) => NavTrackPoint(
  timestamp: timestamp,
  north: north,
  east: east,
  depth: depth,
  speed: speed,
  temperature: temperature,
  batteryVolts: batteryVolts,
);

NavTrack _route(List<NavTrackPoint> points) => NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  startTime: points.isEmpty ? 0 : points.first.timestamp * 1000,
  endTime: points.isEmpty ? 0 : points.last.timestamp * 1000,
  pointCount: points.length,
  points: points,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('NavTrack3dSceneData.fromRoute', () {
    test('times are elapsed seconds from the active range start, not raw '
        'epoch timestamps', () {
      final data = NavTrack3dSceneData.fromRoute(
        _route([
          _p(timestamp: 1700000000, depth: 0),
          _p(timestamp: 1700000010, depth: 5),
          _p(timestamp: 1700000020, depth: 10),
        ]),
      );
      expect(data.times, [0, 10, 20]);
      expect(data.durationSeconds, 20);
      expect(data.maxDepthMeters, 10);
    });

    test('stops at the post-dive GPS fix, same boundary NavTrackStats.of '
        'uses', () {
      // Mirrors nav_track_corrector_test.dart's postDiveFixOnly() fixture:
      // dive, surfaces, then a >50m jump in <=5s (a GPS re-fix).
      final data = NavTrack3dSceneData.fromRoute(
        _route([
          _p(timestamp: 0, north: 0, east: 0, depth: 5),
          _p(timestamp: 20, north: 0, east: 0, depth: 10),
          _p(timestamp: 40, north: 0, east: 0, depth: 0), // surfaces
          _p(timestamp: 42, north: 300, east: 0, depth: 0), // fix jump
          _p(timestamp: 44, north: 302, east: 1, depth: 0),
        ]),
      );
      // Only the first 3 samples (indices 0-2) are in the active range.
      expect(data.times, [0, 20, 40]);
      expect(data.depths, [5, 10, 0]);
    });

    test('falls back to the whole recording when there is no GPS fix at '
        'all (a cave dive, no surface contact)', () {
      final points = [
        for (var i = 0; i < 5; i++)
          _p(timestamp: i * 20, north: i * 10.0, depth: 10.0 + i),
      ];
      final data = NavTrack3dSceneData.fromRoute(_route(points));
      expect(data.times.length, 5);
      expect(data.times.last, 80);
    });

    test('an empty route returns empty series, not a RangeError', () {
      final data = NavTrack3dSceneData.fromRoute(_route([]));
      expect(data.times, isEmpty);
      expect(data.hasProfile, isFalse);
    });

    test('hasProfile is false for fewer than two active samples', () {
      final data = NavTrack3dSceneData.fromRoute(
        _route([_p(timestamp: 0, depth: 5)]),
      );
      expect(data.hasProfile, isFalse);
    });

    test('an exact 0.00V battery sample is treated as missing, not a real '
        'reading (sensor not settled yet, same artifact the detail page '
        'skips in its summary line)', () {
      final data = NavTrack3dSceneData.fromRoute(
        _route([
          _p(timestamp: 0, batteryVolts: 0),
          _p(timestamp: 10, batteryVolts: 3.9),
          _p(timestamp: 20, batteryVolts: 3.8),
        ]),
      );
      expect(data.batteryVolts, [null, 3.9, 3.8]);
    });

    group('availableMetrics', () {
      test('depth is always available', () {
        final data = NavTrack3dSceneData.fromRoute(
          _route([_p(timestamp: 0), _p(timestamp: 10)]),
        );
        expect(data.availableMetrics, contains(TrackSceneMetric.depth));
      });

      test('omits a metric whose series is entirely null', () {
        final data = NavTrack3dSceneData.fromRoute(
          _route([_p(timestamp: 0, speed: 1.0), _p(timestamp: 10, speed: 1.2)]),
        );
        expect(data.availableMetrics, contains(TrackSceneMetric.speed));
        expect(
          data.availableMetrics,
          isNot(contains(TrackSceneMetric.temperature)),
        );
        expect(
          data.availableMetrics,
          isNot(contains(TrackSceneMetric.batteryVoltage)),
        );
      });
    });

    group('zAxisMetrics', () {
      test('depth is offered too, even though it is already the Y axis '
          '-- the diver asked for every metric to be selectable', () {
        final data = NavTrack3dSceneData.fromRoute(
          _route([_p(timestamp: 0, depth: 0), _p(timestamp: 10, depth: 5)]),
        );
        expect(data.zAxisMetrics, contains(TrackSceneMetric.depth));
      });

      test('a metric with only one finite sample is not offered -- no path '
          'to draw', () {
        final data = NavTrack3dSceneData.fromRoute(
          _route([
            _p(timestamp: 0, speed: 1.0),
            _p(timestamp: 10, speed: null),
          ]),
        );
        expect(data.zAxisMetrics, isNot(contains(TrackSceneMetric.speed)));
      });

      test('a metric with two or more finite samples is offered', () {
        final data = NavTrack3dSceneData.fromRoute(
          _route([
            _p(timestamp: 0, speed: 1.0, temperature: 20),
            _p(timestamp: 10, speed: 1.2, temperature: 18),
          ]),
        );
        expect(data.zAxisMetrics, contains(TrackSceneMetric.speed));
        expect(data.zAxisMetrics, contains(TrackSceneMetric.temperature));
        expect(
          data.zAxisMetrics,
          isNot(contains(TrackSceneMetric.batteryVoltage)),
        );
      });
    });
  });
}
