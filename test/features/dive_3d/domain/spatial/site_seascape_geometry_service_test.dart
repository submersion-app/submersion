import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
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
  List<SiteFeatureMarkerInput> features = const [],
}) => SiteSeascapeInput(
  grid: grid(),
  center: const GeoPoint(12.151, -68.299),
  siteName: 'Salt Pier',
  siteMaxDepth: 30,
  divePaths: paths,
  nearbySites: nearby,
  features: features,
);

/// Layers minus the contour/wall overlays this feature added, so the
/// original structural-count assertions keep measuring what they meant.
List<SceneLayer> structuralLayers(Scene3d scene) => [
  for (final l in scene.layers)
    if (l.overlay != SceneOverlay.contours &&
        l.overlay != SceneOverlay.steepWalls)
      l,
];

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
    expect(structuralLayers(scene).length, 3);
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
      expect(structuralLayers(scene).length, 6);
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

  test('real terrain gains contour and water-gated layers plus labels', () {
    // Grid sloping 5 -> 45 m: auto levels 5..45, 8 rendered lines (see
    // contour_builder_test for the hand-derived count), major 25 labeled.
    final slopeGrid = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 100.0 / 110540.0,
      cellSizeLonDeg: 100.0 / 111320.0,
      rows: 3,
      cols: 3,
      depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    final result = service.buildWithLabels(
      SiteSeascapeInput(
        grid: slopeGrid,
        center: const GeoPoint(0, 0),
        siteName: 'Test',
        divePaths: const [],
        nearbySites: const [],
      ),
    );
    final overlays = result.scene.layers.map((l) => l.overlay).toList();
    expect(overlays.where((o) => o == SceneOverlay.contours), hasLength(8));
    expect(overlays.last, SceneOverlay.water);
    expect(result.contourLabels.single.text, '25 m');
    // Contours ride the terrain surface, so they depth-sort WITH it.
    expect(
      result.scene.layers
          .where((l) => l.overlay == SceneOverlay.contours)
          .every((l) => l.drapedOnTerrain),
      isTrue,
    );
    expect(result.scene.layers.last.drapedOnTerrain, isFalse); // water
    // 5 -> 45 over two 100 m cells is 20 m per cell: atan(0.2) = 11.3
    // degrees, below the default 22, so no wall layer.
    expect(overlays.contains(SceneOverlay.steepWalls), isFalse);
  });

  test('an imagery frame flows through to terrain UVs', () {
    final slopeGrid = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 100.0 / 110540.0,
      cellSizeLonDeg: 100.0 / 111320.0,
      rows: 3,
      cols: 3,
      depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    const frame = TerrainImageryFrame(
      u0MercX: 0.4,
      u1MercX: 0.6,
      v0MercY: 0.4,
      v1MercY: 0.6,
      whiteU: 0.5,
      whiteV: 0.99,
    );
    final result = service.buildWithLabels(
      SiteSeascapeInput(
        grid: slopeGrid,
        center: const GeoPoint(0, 0),
        siteName: 'Test',
        divePaths: const [],
        nearbySites: const [],
        imageryFrame: frame,
      ),
    );
    expect(result.scene.layers.first.mesh.textureCoordinates, isNotNull);
  });

  test('steep terrain gains a wall layer once the threshold allows', () {
    final wallGrid = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 100.0 / 110540.0,
      cellSizeLonDeg: 100.0 / 111320.0,
      rows: 2,
      cols: 2,
      depthsMeters: const [10, 10, 60, 60],
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    final result = service.buildWithLabels(
      SiteSeascapeInput(
        grid: wallGrid,
        center: const GeoPoint(0, 0),
        siteName: 'Wall',
        divePaths: const [],
        nearbySites: const [],
        appearance: const SeascapeAppearance(wallAngleDeg: 20),
      ),
    );
    expect(
      result.scene.layers.where((l) => l.overlay == SceneOverlay.steepWalls),
      hasLength(1),
    );
    expect(
      result.scene.layers
          .firstWhere((l) => l.overlay == SceneOverlay.steepWalls)
          .drapedOnTerrain,
      isTrue,
    );
  });

  test('a feature with a recorded depth is placed at that depth', () {
    final result = const SiteSeascapeGeometryService().buildWithLabels(
      input(
        features: const [
          SiteFeatureMarkerInput(
            id: 'f-1',
            typeName: 'wreck',
            label: 'Hilma Hooker',
            offset: (east: 10, north: 10),
            depthMeters: 15,
          ),
        ],
      ),
    );

    final marker = result.scene.markers.firstWhere(
      (m) => m.kind == SceneMarkerKind.siteFeature,
    );
    expect(marker.refId, 'f-1');
    expect(marker.label, 'Hilma Hooker');
    // The scene's own projection maps 15 m; deeper is more negative, and
    // the marker must sit below the surface float used for site pins.
    final sitePin = result.scene.markers.firstWhere(
      (m) => m.kind == SceneMarkerKind.site,
    );
    expect(marker.y, lessThan(sitePin.y));
  });

  test('a depthless feature drapes on the sampled seafloor', () {
    final result = const SiteSeascapeGeometryService().buildWithLabels(
      input(
        features: const [
          // Grid origin cell (20 m of water) sits at the site's
          // south-west corner, about 111 m south and west of center.
          SiteFeatureMarkerInput(
            id: 'f-2',
            typeName: 'mooring',
            label: '',
            offset: (east: -109, north: -111),
          ),
        ],
      ),
    );

    final marker = result.scene.markers.firstWhere(
      (m) => m.kind == SceneMarkerKind.siteFeature,
    );
    // Label falls back to the type name when the diver left it blank.
    expect(marker.label, 'mooring');
    // Draped, not floating: below the surface pin height.
    final sitePin = result.scene.markers.firstWhere(
      (m) => m.kind == SceneMarkerKind.site,
    );
    expect(marker.y, lessThan(sitePin.y));
  });

  test('no features means no feature markers', () {
    final result = const SiteSeascapeGeometryService().buildWithLabels(input());
    expect(
      result.scene.markers.where((m) => m.kind == SceneMarkerKind.siteFeature),
      isEmpty,
    );
  });
}
