import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_surface.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

BathymetryGrid grid() => BathymetryGrid(
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

void main() {
  const center = GeoPoint(12.1505, -68.299);

  test('pick grid shares the terrain mesh vertices with matching indexing', () {
    final g = grid();
    final b = BathymetryTerrainBuilder.enuBounds(g, center);
    final proj = SpatialProjection(
      minEast: b.minEast,
      maxEast: b.maxEast,
      minNorth: b.minNorth,
      maxNorth: b.maxNorth,
      maxDepth: 90,
    );
    final terrain = BathymetryTerrainBuilder.build(
      grid: g,
      center: center,
      projection: proj,
    );
    final pickGrid = seascapePickGrid(g, terrain.terrain);
    expect(pickGrid.isEmpty, isFalse);
    expect(pickGrid.columns, g.rows);
    expect(pickGrid.compartments, g.cols);
    // Pick index (col=row, comp=col) must address the SAME vertex the mesh
    // stores at row*cols + col — pixel-perfect alignment by construction.
    for (var row = 0; row < g.rows; row++) {
      for (var c = 0; c < g.cols; c++) {
        final (x, y, z) = pickGrid.positionAt(row, c);
        final vi = (row * g.cols + c) * 3;
        expect(x, terrain.terrain.positions[vi]);
        expect(y, terrain.terrain.positions[vi + 1]);
        expect(z, terrain.terrain.positions[vi + 2]);
      }
    }
  });

  test('a mesh that does not match the grid yields an empty pick grid', () {
    final g = grid();
    final b = BathymetryTerrainBuilder.enuBounds(g, center);
    final proj = SpatialProjection(
      minEast: b.minEast,
      maxEast: b.maxEast,
      minNorth: b.minNorth,
      maxNorth: b.maxNorth,
      maxDepth: 90,
    );
    // Water plane: 4 vertices, not rows*cols.
    final water = BathymetryTerrainBuilder.build(
      grid: g,
      center: center,
      projection: proj,
    ).water;
    expect(seascapePickGrid(g, water).isEmpty, isTrue);
  });

  test('cell info maps a pick to latitude, longitude, and depth', () {
    final g = grid();
    // pick.col = grid row, pick.comp = grid col.
    const pick = TissuePick(col: 1, comp: 2, screenPos: Offset.zero);
    final info = seascapeCellInfo(g, pick);
    expect(info.latitude, closeTo(12.151, 1e-9)); // origin + 1 lat step
    expect(info.longitude, closeTo(-68.298, 1e-9)); // origin + 2 lon steps
    expect(info.depthMeters, 15);
  });

  test('land and nodata cells report no depth', () {
    final g = grid();
    const land = TissuePick(col: 0, comp: 2, screenPos: Offset.zero);
    expect(seascapeCellInfo(g, land).depthMeters, isNull); // -8 = land
    const nodata = TissuePick(col: 1, comp: 1, screenPos: Offset.zero);
    expect(seascapeCellInfo(g, nodata).depthMeters, isNull);
  });
}
