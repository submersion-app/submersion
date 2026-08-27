import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/grid_sampling.dart';

void main() {
  final grid = BathymetryGrid(
    originLat: 0,
    originLon: 0,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.001,
    rows: 2,
    cols: 2,
    depthsMeters: const [10, 20, null, -2],
    sourceId: 't',
    resolutionMeters: 100,
    fetchedAt: DateTime.utc(2026, 8, 16),
  );

  test('sampleGridDepth picks the nearest cell and rejects outside/land', () {
    // Nearest cell (0,0) = 10 m of water.
    expect(sampleGridDepth(grid, 0.0001, 0.0001), 10);
    // Cell (1,0) is nodata; a guess would be worse than a blank field.
    expect(sampleGridDepth(grid, 0.0009, 0.0001), isNull);
    // Cell (1,1) is land (depth <= 0).
    expect(sampleGridDepth(grid, 0.0009, 0.0009), isNull);
    // Outside the grid entirely.
    expect(sampleGridDepth(grid, 0.5, 0.5), isNull);
    expect(sampleGridDepth(grid, -0.5, 0), isNull);
  });

  test('rounding picks the nearer neighbour, not the floor', () {
    // 0.0006 deg is nearer row 1 than row 0; that cell is nodata.
    expect(sampleGridDepth(grid, 0.0006, 0.0001), isNull);
    // 0.0004 deg still rounds to row 0.
    expect(sampleGridDepth(grid, 0.0004, 0.0001), 10);
  });
}
