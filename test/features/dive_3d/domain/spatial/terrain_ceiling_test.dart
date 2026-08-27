import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/terrain_ceiling.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

const _center = GeoPoint(12.0, -68.0);

BathymetryGrid _grid(List<double?> depths, {int rows = 3, int cols = 3}) =>
    BathymetryGrid(
      originLat: 11.99,
      originLon: -68.01,
      cellSizeLatDeg: 0.01,
      cellSizeLonDeg: 0.01,
      rows: rows,
      cols: cols,
      depthsMeters: depths,
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 1, 1),
    );

SpatialProjection _projectionFor(BathymetryGrid grid) {
  final box = BathymetryTerrainBuilder.enuBounds(grid, _center);
  return SpatialProjection(
    minEast: box.minEast,
    maxEast: box.maxEast,
    minNorth: box.minNorth,
    maxNorth: box.maxNorth,
    maxDepth: grid.maxDepthMeters,
  );
}

void main() {
  test('a cell reports the height of its shallowest corner', () {
    // Row-major, south -> north. The south-west cell spans depths
    // 10 / 20 / 30 / 40; its ceiling is the 10 m corner.
    final grid = _grid([10, 20, 25, 30, 40, 45, 50, 55, 60]);
    final proj = _projectionFor(grid);
    final ceiling = TerrainCeiling(
      grid: grid,
      center: _center,
      projection: proj,
    );

    // A point a quarter into the south-west cell, from its origin corner.
    final x = proj.xOf(
      (grid.originLon + grid.cellSizeLonDeg * 0.25 - _center.longitude) *
          108800,
    );
    final z = proj.zOf(
      (grid.originLat + grid.cellSizeLatDeg * 0.25 - _center.latitude) *
          BathymetryTerrainBuilder.metersPerDegLat,
    );
    expect(ceiling.atScene(x, z), closeTo(proj.yOf(10), 0.02));
  });

  test('the ceiling is never below the surface at any mesh vertex', () {
    final grid = _grid([
      5, 90, 12, //
      140, 8, 200,
      30, 400, 60,
    ]);
    final proj = _projectionFor(grid);
    final ceiling = TerrainCeiling(
      grid: grid,
      center: _center,
      projection: proj,
    );
    final mesh = BathymetryTerrainBuilder.build(
      grid: grid,
      center: _center,
      projection: proj,
    ).terrain;

    for (var i = 0; i < mesh.vertexCount; i++) {
      final x = mesh.positions[i * 3];
      final y = mesh.positions[i * 3 + 1];
      final z = mesh.positions[i * 3 + 2];
      expect(
        ceiling.atScene(x, z),
        greaterThanOrEqualTo(y - 1e-6),
        reason: 'vertex $i sits above its own cell ceiling',
      );
    }
  });

  test('points outside the grid clamp to the nearest edge cell', () {
    final grid = _grid([10, 20, 25, 30, 40, 45, 50, 55, 60]);
    final proj = _projectionFor(grid);
    final ceiling = TerrainCeiling(
      grid: grid,
      center: _center,
      projection: proj,
    );
    expect(ceiling.atScene(-1000, -1000), isA<double>());
    expect(ceiling.atScene(1000, 1000), isA<double>());
    expect(ceiling.atScene(-1000, -1000).isFinite, isTrue);
  });

  test('land and nodata report the surface the mesh actually draws', () {
    // A -5000 m sample is land far above any real cap: the mesh clamps it,
    // and the ceiling has to report the clamped height, not the raw one.
    final grid = _grid([null, -5000, 20, 30, 40, 45, 50, 55, 60]);
    final proj = _projectionFor(grid);
    final ceiling = TerrainCeiling(
      grid: grid,
      center: _center,
      projection: proj,
    );
    final mesh = BathymetryTerrainBuilder.build(
      grid: grid,
      center: _center,
      projection: proj,
    ).terrain;
    final drawnLandY = mesh.positions[1 * 3 + 1]; // node (row 0, col 1)
    expect(drawnLandY, greaterThan(0), reason: 'land sits above the waterline');
    expect(
      drawnLandY,
      lessThan(5000),
      reason: 'and is capped, not raw elevation',
    );
    // The south-west cell holds that land node, so its ceiling is that height.
    expect(
      ceiling.atScene(mesh.positions[0], mesh.positions[2]),
      closeTo(drawnLandY, 1e-6),
    );
  });
}
