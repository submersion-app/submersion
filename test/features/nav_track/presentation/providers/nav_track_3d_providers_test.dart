import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_3d_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

NavTrackPoint _p(int timestamp, double depth, {double? speed}) => NavTrackPoint(
  timestamp: timestamp,
  north: 0,
  east: 0,
  depth: depth,
  speed: speed,
);

NavTrack _route(List<NavTrackPoint> points) => NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  startTime: points.first.timestamp * 1000,
  endTime: points.last.timestamp * 1000,
  pointCount: points.length,
  points: points,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ProviderContainer _makeContainer(NavTrack? route) {
  final container = ProviderContainer(
    overrides: [navTrackByIdProvider('r1').overrideWith((ref) async => route)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('navTrack3dSceneDataProvider', () {
    test('returns null when the route does not exist', () async {
      final container = _makeContainer(null);
      final data = await container.read(
        navTrack3dSceneDataProvider('r1').future,
      );
      expect(data, isNull);
    });

    test(
      'returns null when the route has fewer than two active samples',
      () async {
        final container = _makeContainer(_route([_p(0, 5)]));
        final data = await container.read(
          navTrack3dSceneDataProvider('r1').future,
        );
        expect(data, isNull);
      },
    );

    test('returns scene data for a usable profile', () async {
      final container = _makeContainer(
        _route([_p(0, 0), _p(10, 5), _p(20, 10)]),
      );
      final data = await container.read(
        navTrack3dSceneDataProvider('r1').future,
      );
      expect(data, isNotNull);
      expect(data!.maxDepthMeters, 10);
    });
  });

  group('navTrack3dGeometryProvider', () {
    test('is null for a profileless route', () async {
      final container = _makeContainer(_route([_p(0, 5)]));
      final scene = await container.read(
        navTrack3dGeometryProvider((
          trackId: 'r1',
          colorMetric: TrackSceneMetric.depth,
          zMetric: null,
        )).future,
      );
      expect(scene, isNull);
    });

    test('builds synchronously for a small profile', () async {
      final container = _makeContainer(
        _route([
          _p(0, 0, speed: 1.0),
          _p(10, 5, speed: 1.2),
          _p(20, 10, speed: 0.9),
        ]),
      );
      final scene = await container.read(
        navTrack3dGeometryProvider((
          trackId: 'r1',
          colorMetric: TrackSceneMetric.speed,
          zMetric: null,
        )).future,
      );
      expect(scene, isNotNull);
      expect(scene!.layers, hasLength(2));
    });

    test('a Z metric moves the scrub path off the flat plane', () async {
      final container = _makeContainer(
        _route([
          _p(0, 0, speed: 1.0),
          _p(10, 5, speed: 1.2),
          _p(20, 10, speed: 0.9),
        ]),
      );
      final scene = await container.read(
        navTrack3dGeometryProvider((
          trackId: 'r1',
          colorMetric: TrackSceneMetric.depth,
          zMetric: TrackSceneMetric.speed,
        )).future,
      );
      expect(scene!.scrubPath!.zs, isNot(everyElement(0)));
    });
  });
}
