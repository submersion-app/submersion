import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
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
    // Still terrain + ribbon + 2 pins + water.
    expect(scene.layers.length, 5);
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
}
