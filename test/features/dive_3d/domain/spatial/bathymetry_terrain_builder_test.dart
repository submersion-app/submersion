import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/slippy_tiles.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A frame that maps u/v 0..1 exactly onto the grid's VERTEX extent (cell
/// centers), so corner vertices land on 0 and 1.
TerrainImageryFrame _frameFor(BathymetryGrid g) {
  final west = g.originLon;
  final east = g.originLon + g.cellSizeLonDeg * (g.cols - 1);
  final north = g.originLat + g.cellSizeLatDeg * (g.rows - 1);
  final south = g.originLat;
  return TerrainImageryFrame(
    u0MercX: mercatorX(west),
    u1MercX: mercatorX(east),
    v0MercY: mercatorY(north),
    v1MercY: mercatorY(south),
    whiteU: 0.5,
    whiteV: 0.99,
  );
}

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

  group('depth ramp options', () {
    test('depthColor banded quantizes into 10 segment centers', () {
      // t = 0.0 and t = 0.09 both land in segment 0 (center 0.05);
      // t = 0.95 lands in segment 9 (center 0.95).
      expect(
        BathymetryTerrainBuilder.depthColor(0.0, banded: true),
        BathymetryTerrainBuilder.depthColor(0.09, banded: true),
      );
      expect(
        BathymetryTerrainBuilder.depthColor(0.0, banded: true),
        isNot(BathymetryTerrainBuilder.depthColor(0.11, banded: true)),
      );
      expect(
        BathymetryTerrainBuilder.depthColor(1.0, banded: true),
        BathymetryTerrainBuilder.depthColor(0.95, banded: true),
      );
      // Continuous stays continuous.
      expect(
        BathymetryTerrainBuilder.depthColor(0.0),
        isNot(BathymetryTerrainBuilder.depthColor(0.09)),
      );
    });

    test('rampMaxDepthMeters clamps deeper terrain to the deepest color', () {
      // One shallow (10 m) and one deep (80 m) vertex; ramp max 20 m: the
      // 80 m vertex must carry exactly the deep color, and the 10 m vertex
      // the t = 0.5 color.
      final rampGrid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 100.0 / 110540.0,
        cellSizeLonDeg: 100.0 / 111320.0,
        rows: 2,
        cols: 2,
        depthsMeters: const [10, 80, 10, 80],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 15),
      );
      final rampProj = SpatialProjection(
        minEast: 0,
        maxEast: 100,
        minNorth: 0,
        maxNorth: 100,
        maxDepth: 80,
      );
      final terrain = BathymetryTerrainBuilder.build(
        grid: rampGrid,
        center: const GeoPoint(0, 0),
        projection: rampProj,
        rampMaxDepthMeters: 20,
      );
      const deep = BathymetryTerrainBuilder.deepColor;
      // Vertex 1 (row 0, col 1) is the 80 m cell.
      expect(terrain.terrain.colors[3], closeTo(deep.r, 1e-4));
      expect(terrain.terrain.colors[4], closeTo(deep.g, 1e-4));
      final half = BathymetryTerrainBuilder.depthColor(0.5);
      expect(terrain.terrain.colors[0], closeTo(half.r, 1e-4));
    });

    test('a frame yields normalized UVs with corners on 0 and 1', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
        imageryFrame: _frameFor(grid),
      );
      final uv = t.terrain.textureCoordinates;
      expect(uv, isNotNull);
      expect(uv!.length, grid.rows * grid.cols * 2);
      // Vertex 0 = row 0 (south), col 0 (west): u = 0, v = 1.
      expect(uv[0], closeTo(0.0, 1e-9));
      expect(uv[1], closeTo(1.0, 1e-9));
      // Last vertex = north-east corner: u = 1, v = 0.
      expect(uv[uv.length - 2], closeTo(1.0, 1e-9));
      expect(uv[uv.length - 1], closeTo(0.0, 1e-9));
    });

    test('no frame means no UVs (existing behavior untouched)', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
      );
      expect(t.terrain.textureCoordinates, isNull);
    });

    test('imagery mode paints every terrain vertex white', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
        imageryFrame: _frameFor(grid),
        surfaceMode: SeascapeSurfaceMode.imagery,
      );
      for (var i = 0; i < t.terrain.colors.length; i++) {
        expect(t.terrain.colors[i], 1.0);
      }
    });

    test('blend mode keeps the ramp colors', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
        imageryFrame: _frameFor(grid),
        surfaceMode: SeascapeSurfaceMode.blend,
      );
      final plain = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
      );
      expect(t.terrain.colors, plain.terrain.colors);
    });

    test('default build output is unchanged (regression guard)', () {
      final a = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
      );
      final b = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
        rampBanded: false,
      );
      expect(a.terrain.colors, b.terrain.colors);
    });
  });
}
