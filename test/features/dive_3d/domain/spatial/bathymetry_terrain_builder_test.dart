import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  // 2x3 grid centered near the origin: wet, land, and nodata cells.
  final grid = BathymetryGrid(
    originLat: 12.15,
    originLon: -68.30,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.001,
    rows: 2,
    cols: 3,
    depthsMeters: const [30, 60, -8, 90, null, 15],
    sourceId: 'gmrt',
    resolutionMeters: 61,
    fetchedAt: DateTime.utc(2026, 7, 28),
  );
  const center = GeoPoint(12.1505, -68.299);

  SpatialProjection proj() {
    final b = BathymetryTerrainBuilder.enuBounds(grid, center);
    return SpatialProjection(
      minEast: b.minEast,
      maxEast: b.maxEast,
      minNorth: b.minNorth,
      maxNorth: b.maxNorth,
      maxDepth: 90,
    );
  }

  test('enuBounds spans the grid symmetrically around its cells', () {
    final b = BathymetryTerrainBuilder.enuBounds(grid, center);
    expect(b.minEast, lessThan(0)); // origin lon is west of center
    expect(b.maxEast, greaterThan(0));
    expect(
      b.maxEast - b.minEast,
      closeTo(0.002 * 111320 * 0.977, 20), // 2 lon steps, cos ~12.15 deg
    );
    expect(b.maxNorth - b.minNorth, closeTo(0.001 * 110540, 5));
  });

  test('terrain has one vertex per cell and full quad indices', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    expect(t.terrain.vertexCount, 6);
    expect(t.terrain.indices.length, (2 - 1) * (3 - 1) * 6);
    expect(t.water.vertexCount, 4);
  });

  test('wet cells sit below the waterline, colored by the depth ramp', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    // Vertex 0 = row 0, col 0 (depth 30): y must be negative.
    expect(t.terrain.positions[1], lessThan(0));
    // Deeper cell (90 m, vertex 3) is lower than shallower (30 m, vertex 0).
    expect(t.terrain.positions[3 * 3 + 1], lessThan(t.terrain.positions[1]));
  });

  test('land cells rise above the waterline with capped height', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    // Vertex 2 = row 0, col 2 (depth -8 = land).
    final landY = t.terrain.positions[2 * 3 + 1];
    expect(landY, greaterThan(0));
    // Cap: never higher than 15% of maxDepth's scene height.
    expect(landY, lessThanOrEqualTo(0.15 * 6.0 + 1e-9));
  });

  test('nodata cells render as shoreline at y == 0', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    // Vertex 4 = row 1, col 1 (null).
    expect(t.terrain.positions[4 * 3 + 1], 0);
  });

  test('water plane sits at y == 0', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    for (var i = 0; i < 4; i++) {
      expect(t.water.positions[i * 3 + 1], 0);
    }
  });
}
