import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

ReckonedPath path() => const ReckonedPath(
  points: [
    ReckonedPoint(east: 0, north: 0, depth: 5, timeSeconds: 0),
    ReckonedPoint(east: 30, north: 10, depth: 18, timeSeconds: 300),
    ReckonedPoint(east: 60, north: 20, depth: 12, timeSeconds: 600),
  ],
  reconstructed: true,
  minEast: 0,
  maxEast: 60,
  minNorth: 0,
  maxNorth: 20,
  maxDepth: 18,
  durationSeconds: 600,
);

BathymetryGrid grid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 4,
  cols: 5,
  depthsMeters: List<double?>.generate(20, (i) => 30.0 + i),
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

void main() {
  const service = SpatialGeometryService();
  const center = GeoPoint(12.1515, -68.298);

  test('without a grid the synthesized terrain is unchanged (28x28)', () {
    final scene = service.build(path(), siteMaxDepth: 30);
    // Layer 0 is the terrain: 28x28 synthesized heightmap.
    expect(scene.layers.first.mesh.vertexCount, 28 * 28);
    expect(scene.layers.length, 5);
  });

  test('with a grid the terrain is the bathymetry mesh, path intact', () {
    final scene = service.build(
      path(),
      siteMaxDepth: 30,
      grid: grid(),
      gridCenter: center,
      pathAnchor: (east: 15.0, north: -10.0),
    );
    // Terrain now has one vertex per grid cell.
    expect(scene.layers.first.mesh.vertexCount, 4 * 5);
    // Still terrain + ribbon + 2 pins + water (contour overlays aside).
    final structural = scene.layers
        .where((l) => l.overlay != SceneOverlay.contours)
        .length;
    expect(structural, 5);
    // Depth budget covers the deepest of path/grid/site.
    expect(scene.bounds.maxDepthMeters, 49); // grid max = 30 + 19
    // Scrub path still spans the dive's timeline.
    expect(scene.scrubPath, isNotNull);
    expect(scene.scrubPath!.normalizedTimes.last, closeTo(1.0, 1e-9));
  });

  test('grid without a center is ignored (falls back to synthesized)', () {
    final scene = service.build(path(), grid: grid());
    expect(scene.layers.first.mesh.vertexCount, 28 * 28);
  });

  test('bathymetry scene gains contours and labels', () {
    // Sloping 5 -> 45 m grid (see contour_builder_test): 8 contour lines,
    // one labeled major (25 m).
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
    final built = service.buildWithFrame(
      path(),
      grid: slopeGrid,
      gridCenter: const GeoPoint(0, 0),
    );
    final overlays = built.scene.layers.map((l) => l.overlay).toList();
    expect(overlays.where((o) => o == SceneOverlay.contours), hasLength(8));
    expect(overlays.last, SceneOverlay.water);
    expect(built.contourLabels.single.text, '25 m');
  });

  test('synthesized fallback gets no contours or walls, water stays gated', () {
    final built = service.buildWithFrame(path());
    final overlays = built.scene.layers.map((l) => l.overlay).toList();
    expect(overlays.contains(SceneOverlay.contours), isFalse);
    expect(overlays.contains(SceneOverlay.steepWalls), isFalse);
    expect(overlays.last, SceneOverlay.water);
    expect(built.contourLabels, isEmpty);
  });
}
