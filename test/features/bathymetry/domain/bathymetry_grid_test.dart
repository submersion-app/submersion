import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

BathymetryGrid grid(List<double?> depths, {int rows = 2, int cols = 3}) =>
    BathymetryGrid(
      originLat: 12.14,
      originLon: -68.31,
      cellSizeLatDeg: 0.004,
      cellSizeLonDeg: 0.004,
      rows: rows,
      cols: cols,
      depthsMeters: depths,
      sourceId: 'test',
      resolutionMeters: 450,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );

void main() {
  test('depthAt reads row-major cells', () {
    final g = grid([1, 2, 3, 4, 5, 6]);
    expect(g.depthAt(0, 0), 1);
    expect(g.depthAt(1, 2), 6);
  });

  test('wetFraction counts wet cells among known cells only', () {
    // 2 wet (+), 1 land (-), 1 nodata, 2 wet => 4 wet / 5 known.
    final g = grid([10, 20, -5, null, 30, 40]);
    expect(g.wetFraction, closeTo(4 / 5, 1e-9));
  });

  test('wetFraction is 0 for an all-null grid', () {
    expect(grid([null, null, null, null, null, null]).wetFraction, 0);
  });

  test('maxDepthMeters ignores land and nodata', () {
    expect(grid([10, -50, null, 42, 7, 3]).maxDepthMeters, 42);
  });

  test('downsampleTo caps both dimensions with strided cells', () {
    final depths = List<double?>.generate(6 * 6, (i) => i.toDouble());
    final g = grid(depths, rows: 6, cols: 6);
    final d = g.downsampleTo(3);
    expect(d.rows, 3);
    expect(d.cols, 3);
    expect(d.depthAt(0, 0), 0); // stride 2 keeps cells 0,2,4
    expect(d.depthAt(1, 1), 14); // row 2, col 2 of original
    expect(d.cellSizeLatDeg, closeTo(0.008, 1e-12));
  });

  test('non-square downsampling reports the coarser stride resolution', () {
    // 9 rows x 3 cols capped at 3: stepR = 3, stepC = 1 — the effective
    // spacing is set by the coarser stride, so the provenance resolution
    // must scale by it, never claiming more detail than the grid has.
    final depths = List<double?>.generate(9 * 3, (i) => i.toDouble());
    final g = grid(depths, rows: 9, cols: 3);
    final d = g.downsampleTo(3);
    expect(d.rows, 3);
    expect(d.cols, 3);
    expect(d.resolutionMeters, 450 * 3);
  });

  test('downsampleTo is identity when already small enough', () {
    final g = grid([1, 2, 3, 4, 5, 6]);
    expect(identical(g.downsampleTo(120), g), isTrue);
  });

  test('json round-trip preserves all fields including nulls', () {
    final g = grid([10.5, null, -3, 4, 5, 6]);
    final back = BathymetryGrid.fromJson(g.toJson());
    expect(back.depthsMeters, g.depthsMeters);
    expect(back.originLat, g.originLat);
    expect(back.cellSizeLonDeg, g.cellSizeLonDeg);
    expect(back.rows, g.rows);
    expect(back.cols, g.cols);
    expect(back.sourceId, 'test');
    expect(back.resolutionMeters, 450);
    expect(back.fetchedAt, DateTime.utc(2026, 7, 28));
  });
}
