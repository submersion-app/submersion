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

  test('downsampleTo caps both dimensions with block means', () {
    final depths = List<double?>.generate(6 * 6, (i) => i.toDouble());
    final g = grid(depths, rows: 6, cols: 6);
    final d = g.downsampleTo(3);
    expect(d.rows, 3);
    expect(d.cols, 3);
    // Stride 2, so each output cell is the mean of a 2x2 block.
    expect(d.depthAt(0, 0), closeTo(3.5, 1e-9)); // cells 0, 1, 6, 7
    expect(d.depthAt(1, 1), closeTo(17.5, 1e-9)); // cells 14, 15, 20, 21
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

  group('knownFraction', () {
    test('is the fraction of non-null cells', () {
      final g = grid([10.0, null, 30.0, null], rows: 1, cols: 4);
      expect(g.knownFraction, 0.5);
    });

    test('is zero for an entirely empty grid', () {
      final g = grid([null, null], rows: 1, cols: 2);
      expect(g.knownFraction, 0.0);
    });
  });

  group('downsampleTo averaging', () {
    test('averages each block instead of picking its first sample', () {
      // 4x4 halved to 2x2: each output cell is the mean of a 2x2 block.
      final g = grid(
        const [
          1.0, 3.0, 10.0, 20.0, //
          5.0, 7.0, 30.0, 40.0, //
          100.0, 100.0, 0.0, 0.0, //
          100.0, 100.0, 0.0, 0.0, //
        ],
        rows: 4,
        cols: 4,
      );
      final d = g.downsampleTo(2);
      expect(d.rows, 2);
      expect(d.cols, 2);
      expect(d.depthAt(0, 0), closeTo(4.0, 1e-9));
      expect(d.depthAt(0, 1), closeTo(25.0, 1e-9));
      expect(d.depthAt(1, 0), closeTo(100.0, 1e-9));
      expect(d.depthAt(1, 1), closeTo(0.0, 1e-9));
    });

    test('averages only the known cells in a block', () {
      final g = grid(const [10.0, null, null, 20.0], rows: 2, cols: 2);
      expect(g.downsampleTo(1).depthAt(0, 0), closeTo(15.0, 1e-9));
    });

    test('an all-nodata block stays nodata', () {
      final g = grid(
        const [
          null, null, 8.0, 8.0, //
          null, null, 8.0, 8.0, //
        ],
        rows: 2,
        cols: 4,
      );
      final d = g.downsampleTo(2);
      expect(d.depthAt(0, 0), isNull);
      expect(d.depthAt(0, 1), closeTo(8.0, 1e-9));
    });

    test('returns the same instance when already within the cap', () {
      final g = grid(const [1.0, 2.0, 3.0, 4.0], rows: 2, cols: 2);
      expect(identical(g.downsampleTo(4), g), isTrue);
    });

    test('scales the resolution claim by the coarser stride', () {
      final g = grid(List<double?>.filled(16, 5.0), rows: 4, cols: 4);
      expect(g.downsampleTo(2).resolutionMeters, closeTo(900.0, 1e-9));
    });

    test('recentres the origin on the block, not on its first sample', () {
      // Origin is the SOUTH-WEST CELL CENTER. Striding sampled the block's
      // first cell, so the origin was already that sample's center and had
      // to stay put. A block MEAN sits at the block's centroid instead,
      // half a stride further north and east, so the origin has to move
      // with it or every cell is reported half a block south-west of the
      // data it holds.
      final g = grid(List<double?>.filled(16, 5.0), rows: 4, cols: 4);
      final d = g.downsampleTo(2);
      // step 2: shift by cell * (step - 1) / 2 = half a cell.
      expect(d.originLat, closeTo(12.14 + 0.004 * 0.5, 1e-12));
      expect(d.originLon, closeTo(-68.31 + 0.004 * 0.5, 1e-12));
    });

    test('recentres by a full cell at stride 3', () {
      final g = grid(List<double?>.filled(81, 5.0), rows: 9, cols: 9);
      final d = g.downsampleTo(3);
      // step 3: shift by cell * (3 - 1) / 2 = one whole cell.
      expect(d.originLat, closeTo(12.14 + 0.004, 1e-12));
      expect(d.originLon, closeTo(-68.31 + 0.004, 1e-12));
    });

    test('preserves the south-west edge of the geographic footprint', () {
      // The invariant that matters downstream: the overlay image, the
      // imagery mosaic and the 3D mesh all derive their bounds from the
      // origin and cell size, so the covered area must not move.
      final g = grid(List<double?>.filled(16, 5.0), rows: 4, cols: 4);
      final d = g.downsampleTo(2);
      expect(
        d.originLat - d.cellSizeLatDeg / 2,
        closeTo(12.14 - 0.004 / 2, 1e-12),
      );
      expect(
        d.originLon - d.cellSizeLonDeg / 2,
        closeTo(-68.31 - 0.004 / 2, 1e-12),
      );
    });

    test('an identity downsample leaves the origin alone', () {
      final g = grid(const [1.0, 2.0, 3.0, 4.0], rows: 2, cols: 2);
      final d = g.downsampleTo(4);
      expect(d.originLat, 12.14);
      expect(d.originLon, -68.31);
    });
  });
}
