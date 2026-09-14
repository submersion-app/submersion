import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/nav_track/application/nav_track_scene_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

import '../../../helpers/mock_providers.dart';

List<NavTrackPoint> _points() => [
  for (var i = 0; i < 10; i++)
    NavTrackPoint(
      timestamp: 1755856800 + i * 10,
      north: i * 10.0,
      east: i * 5.0,
      depth: 5.0 + i,
      distance: i * 11.0,
    ),
];

NavTrack _route({
  double? anchorLatitude,
  double? anchorLongitude,
  List<NavTrackPoint>? points,
}) => NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: points?.length ?? 10,
  anchorLatitude: anchorLatitude,
  anchorLongitude: anchorLongitude,
  points: points ?? _points(),
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Future<ProviderContainer> _container({
  required NavTrack? route,
  Override? bathymetryOverride,
}) async {
  final overrides = await getBaseOverrides();
  final container = ProviderContainer(
    overrides: [
      ...overrides,
      navTrackByIdProvider('r1').overrideWith((ref) async => route),
      bathymetryOverride ??
          bathymetryGridProvider.overrideWith((ref, cell) async => null),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('returns null when the route does not exist', () async {
    final container = await _container(route: null);

    final result = await container.read(navTrackSceneProvider('r1').future);

    expect(result, isNull);
  });

  test('returns null when the route has fewer than two points', () async {
    final container = await _container(
      route: _route(
        points: const [
          NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 1),
        ],
      ),
    );

    final result = await container.read(navTrackSceneProvider('r1').future);

    expect(result, isNull);
  });

  test(
    'builds a synthesized scene without fetching bathymetry when unanchored',
    () async {
      final container = await _container(route: _route());

      final result = await container.read(navTrackSceneProvider('r1').future);

      expect(result, isNotNull);
      expect(result!.scene.layers, isNotEmpty);
      expect(result.bathymetrySourceId, isNull);
      expect(result.grid, isNull);
    },
  );

  test(
    'builds a real-terrain scene from the bathymetry grid when anchored',
    () async {
      final grid = BathymetryGrid(
        originLat: 47.0,
        originLon: 8.0,
        cellSizeLatDeg: 100.0 / 110540.0,
        cellSizeLonDeg: 100.0 / 111320.0,
        rows: 3,
        cols: 3,
        depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
        sourceId: 'gmrt',
        resolutionMeters: 61,
        fetchedAt: DateTime.utc(2026, 8, 15),
      );
      final container = await _container(
        route: _route(anchorLatitude: 47.1, anchorLongitude: 8.2),
        bathymetryOverride: bathymetryGridProvider.overrideWith(
          (ref, cell) async => grid,
        ),
      );

      final result = await container.read(navTrackSceneProvider('r1').future);

      expect(result, isNotNull);
      expect(result!.bathymetrySourceId, 'gmrt');
      expect(result.bathymetryResolutionMeters, 61);
      expect(result.grid, grid);
      expect(result.scene.layers, isNotEmpty);
    },
  );

  test('surfaces the path provenance from the adapted ReckonedPath', () async {
    final container = await _container(route: _route());

    final result = await container.read(navTrackSceneProvider('r1').future);

    expect(result!.pathProvenance, PathProvenance.measured);
  });
}
