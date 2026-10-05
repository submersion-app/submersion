import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/route_window_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// An ~8 km tile whose depth rises 1 m per column (115 m cells).
BathymetryGrid _tile() {
  const n = 70;
  return BathymetryGrid(
    originLat: 47.41 - 35 * 0.00104,
    originLon: -3.022 - 35 * 0.00153,
    cellSizeLatDeg: 0.00104,
    cellSizeLonDeg: 0.00153,
    rows: n,
    cols: n,
    depthsMeters: [
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++) 10.0 + c,
    ],
    sourceId: 'emodnet',
    resolutionMeters: 115,
    fetchedAt: DateTime.utc(2026, 8, 18),
  );
}

ReckonedPath _route() => const ReckonedPath(
  points: [
    ReckonedPoint(east: 0, north: 0, depth: 2, timeSeconds: 0),
    ReckonedPoint(east: 40, north: 30, depth: 18, timeSeconds: 600),
    ReckonedPoint(east: 10, north: 60, depth: 12, timeSeconds: 1200),
  ],
  provenance: PathProvenance.measured,
  minEast: 0,
  maxEast: 40,
  minNorth: 0,
  maxNorth: 60,
  maxDepth: 18,
  durationSeconds: 1200,
);

void main() {
  const center = GeoPoint(47.41, -3.022);

  test('spans exactly the route, padded, around where it is placed', () {
    final grid = routeWindowGrid(
      _tile(),
      center,
      _route(),
      anchor: (east: 100.0, north: -50.0),
    )!;
    final box = BathymetryTerrainBuilder.enuBounds(grid, center);

    // Route 40 x 60 m placed at (100, -50), padded by a quarter of each span.
    expect(box.minEast, closeTo(100 - 10, 0.01));
    expect(box.maxEast, closeTo(140 + 10, 0.01));
    expect(box.minNorth, closeTo(-50 - 15, 0.01));
    expect(box.maxNorth, closeTo(10 + 15, 0.01));
  });

  test('keeps the source depths, interpolated, and its provenance', () {
    final tile = _tile();
    final grid = routeWindowGrid(
      tile,
      center,
      _route(),
      anchor: (east: 0.0, north: 0.0),
    )!;

    // The tile deepens 1 m per 115 m eastward: over an ~60 m window the
    // resampled seafloor varies by well under a metre, all near 45 m.
    final depths = grid.depthsMeters.whereType<double>().toList();
    expect(depths, hasLength(grid.rows * grid.cols));
    for (final d in depths) {
      expect(d, inInclusiveRange(44.0, 46.0));
    }
    expect(grid.sourceId, tile.sourceId);
    expect(grid.resolutionMeters, tile.resolutionMeters);
  });

  test('is null when the route lies outside the tile', () {
    expect(
      routeWindowGrid(
        _tile(),
        center,
        _route(),
        anchor: (east: 20000.0, north: 0.0),
      ),
      isNull,
    );
  });
}
