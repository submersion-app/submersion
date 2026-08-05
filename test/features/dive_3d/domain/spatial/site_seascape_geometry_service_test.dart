import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

BathymetryGrid grid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 3,
  cols: 3,
  depthsMeters: const [20, 25, 30, 25, 30, 35, 30, 35, 40],
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

ReckonedPath path() => const ReckonedPath(
  points: [
    ReckonedPoint(east: 0, north: 0, depth: 5, timeSeconds: 0),
    ReckonedPoint(east: 40, north: 20, depth: 18, timeSeconds: 600),
  ],
  reconstructed: true,
  minEast: 0,
  maxEast: 40,
  minNorth: 0,
  maxNorth: 20,
  maxDepth: 18,
  durationSeconds: 600,
);

SiteSeascapeInput input({
  List<SiteDivePathInput> paths = const [],
  List<NearbySiteInput> nearby = const [],
}) => SiteSeascapeInput(
  grid: grid(),
  center: const GeoPoint(12.151, -68.299),
  siteName: 'Salt Pier',
  siteMaxDepth: 30,
  divePaths: paths,
  nearbySites: nearby,
);

void main() {
  const service = SiteSeascapeGeometryService();

  test('offsetReckonedPath shifts points and bounds; identity at zero', () {
    final p = path();
    expect(identical(offsetReckonedPath(p, (east: 0, north: 0)), p), isTrue);
    final moved = offsetReckonedPath(p, (east: 100, north: -50));
    expect(moved.points.first.east, 100);
    expect(moved.points.first.north, -50);
    expect(moved.maxEast, 140);
    expect(moved.minNorth, -50);
    expect(moved.maxDepth, p.maxDepth); // untouched
  });

  test('bare scene: terrain, site pin, water; a site marker; no scrub', () {
    final scene = service.build(input());
    expect(scene.layers.length, 3);
    expect(scene.scrubPath, isNull);
    final site = scene.markers.single;
    expect(site.kind, SceneMarkerKind.site);
    expect(site.label, 'Salt Pier');
    expect(site.y, greaterThan(0)); // floats above the surface
  });

  test(
    'dive paths add ribbon + entry/exit pins gated by the paths overlay',
    () {
      final scene = service.build(
        input(
          paths: [
            SiteDivePathInput(
              diveId: 'd1',
              path: path(),
              anchor: (east: 10, north: 5),
            ),
          ],
        ),
      );
      // terrain + (ribbon + 2 pins) + site pin + water = 6.
      expect(scene.layers.length, 6);
      final gated = scene.layers
          .where((l) => l.overlay == SceneOverlay.paths)
          .length;
      expect(gated, 3);
    },
  );

  test('nearby sites become nearbySite markers at their offsets', () {
    final scene = service.build(
      input(
        nearby: [
          const NearbySiteInput(
            siteId: 's2',
            name: 'Angel City',
            offset: (east: 80, north: -40),
          ),
        ],
      ),
    );
    final nearby = scene.markers
        .where((m) => m.kind == SceneMarkerKind.nearbySite)
        .single;
    expect(nearby.label, 'Angel City');
    expect(nearby.refId, 's2');
    expect(nearby.z, isNot(0)); // positioned in 3D, not billboarded at 0
  });

  test('bounds fit terrain depth and keep surface markers visible', () {
    final scene = service.build(input());
    expect(scene.bounds.maxDepthMeters, 40); // grid max beats siteMaxDepth
    expect(scene.bounds.sceneMaxY, greaterThan(0));
  });
}
