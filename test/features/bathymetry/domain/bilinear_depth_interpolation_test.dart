import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bilinear_depth_interpolation.dart';

void main() {
  // originLat/originLon are cell (0, 0)'s CENTER, so with a 1-degree cell
  // size the grid's true footprint runs from -0.5 to 2.5 in both lat and
  // lon, not just 0 to 2 (the span between the first and last centers).
  final grid = BathymetryGrid(
    originLat: 0,
    originLon: 0,
    cellSizeLatDeg: 1,
    cellSizeLonDeg: 1,
    rows: 3,
    cols: 3,
    depthsMeters: const [10, 20, 30, 40, 50, 60, 70, 80, 90],
    sourceId: 't',
    resolutionMeters: 100,
    fetchedAt: DateTime.utc(2026, 8, 16),
  );

  test('interpolates normally between four interior cells', () {
    // Midpoint of cells (0,0)=10, (0,1)=20, (1,0)=40, (1,1)=50.
    expect(bilinearInterpolateDepth(grid, 0.5, 0.5), 30);
  });

  test(
    'a point in the south half-margin of row 0 is still inside the grid',
    () {
      // Half a cell south of row 0's center: within the grid's true
      // footprint, so this must not fall back to null just because there is
      // no row -1 to blend against.
      expect(bilinearInterpolateDepth(grid, -0.4, 0), 10);
    },
  );

  test('a point in the west half-margin of col 0 is still inside the grid', () {
    expect(bilinearInterpolateDepth(grid, 0, -0.4), 10);
  });

  test(
    'a point in the north half-margin of the last row is still inside the grid',
    () {
      // Half a cell north of row 2 (the last row)'s center.
      expect(bilinearInterpolateDepth(grid, 2.4, 0), 70);
    },
  );

  test(
    'a point in the east half-margin of the last column is still inside the grid',
    () {
      expect(bilinearInterpolateDepth(grid, 0, 2.4), 30);
    },
  );

  test('a corner margin clamps to the nearest edge cell on both axes', () {
    // South-east corner margin: still within the footprint on both axes,
    // but with no row below 0 or column beyond 2 to blend against, so this
    // must resolve to cell (0, 2)'s own value regardless of either weight.
    expect(bilinearInterpolateDepth(grid, -0.4, 2.4), 30);
  });

  test(
    'a point just beyond the half-cell margin is genuinely outside the grid',
    () {
      expect(bilinearInterpolateDepth(grid, -0.6, 0), isNull);
      expect(bilinearInterpolateDepth(grid, 2.6, 0), isNull);
      expect(bilinearInterpolateDepth(grid, 0, -0.6), isNull);
      expect(bilinearInterpolateDepth(grid, 0, 2.6), isNull);
    },
  );

  test(
    'a nodata interior neighbor row does not leak into the south margin',
    () {
      // Row 0 is fully valid, row 1 (the interior neighbor row 0's south
      // margin used to reference) is entirely nodata. A point half a cell
      // south of row 0's center has a blend weight of 0 against row 1, so
      // row 1 being nodata must not affect the result.
      final rowBelowIsHole = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 1,
        cellSizeLonDeg: 1,
        rows: 2,
        cols: 2,
        depthsMeters: const [10, 20, null, null],
        sourceId: 't',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 16),
      );
      expect(bilinearInterpolateDepth(rowBelowIsHole, -0.4, 0.5), 15);
    },
  );

  test(
    'a nodata interior neighbor column does not leak into the west margin',
    () {
      // Column 0 is fully valid, column 1 (the interior neighbor column 0's
      // west margin used to reference) is entirely nodata.
      final colRightIsHole = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 1,
        cellSizeLonDeg: 1,
        rows: 2,
        cols: 2,
        depthsMeters: const [10, null, 30, null],
        sourceId: 't',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 16),
      );
      expect(bilinearInterpolateDepth(colRightIsHole, 0.5, -0.4), 20);
    },
  );

  test('nodata among the four surrounding cells still yields null', () {
    final withHole = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 1,
      cellSizeLonDeg: 1,
      rows: 2,
      cols: 2,
      depthsMeters: const [10, 20, null, 40],
      sourceId: 't',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 16),
    );
    expect(bilinearInterpolateDepth(withHole, 0.5, 0.5), isNull);
  });
}
