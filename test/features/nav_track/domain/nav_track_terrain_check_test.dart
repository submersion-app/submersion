import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_terrain_check.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _anchor = GeoPoint(47.0, 8.0);

/// A flat grid, 1 degree per cell (comically coarse but easy to reason
/// about), centered on [_anchor], every cell holding [depth] except where
/// overridden.
BathymetryGrid _flatGrid({
  required double depth,
  double resolutionMeters = 10,
  double cellSizeDeg = 0.01,
}) {
  return BathymetryGrid(
    originLat: _anchor.latitude,
    originLon: _anchor.longitude,
    cellSizeLatDeg: cellSizeDeg,
    cellSizeLonDeg: cellSizeDeg,
    rows: 3,
    cols: 3,
    depthsMeters: List<double?>.filled(9, depth),
    sourceId: 'test',
    resolutionMeters: resolutionMeters,
    fetchedAt: DateTime(2026, 1, 1),
  );
}

CorrectedNavTrackPoint _point({
  double east = 0,
  double north = 0,
  double depth = 0,
}) {
  return CorrectedNavTrackPoint(
    timestamp: 0,
    east: east,
    north: north,
    depth: depth,
  );
}

void main() {
  group('summaryLine', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    const result = NavTrackTerrainCheckResult(
      classifications: [
        NavTrackTerrainClass.ok,
        NavTrackTerrainClass.belowSeafloor,
      ],
      penetrationMeters: [0, 13],
      resolutionSupportsBelowSeafloorCheck: true,
    );

    test('shows the deepest penetration in the diver\'s depth unit', () {
      final line = result.summaryLine(
        l10n,
        formatDepth: (meters) => '${(meters * 3.28084).toStringAsFixed(1)}ft',
      );

      expect(line, contains('(max 42.7ft)'));
      expect(line, isNot(contains(' m)')));
    });

    test('omits the penetration when nothing is below the seafloor', () {
      const clear = NavTrackTerrainCheckResult(
        classifications: [NavTrackTerrainClass.ok],
        penetrationMeters: [0],
        resolutionSupportsBelowSeafloorCheck: true,
      );

      final line = clear.summaryLine(
        l10n,
        formatDepth: (_) => fail('no depth to format'),
      );

      expect(line, isNot(contains('max')));
    });
  });

  group('NavTrackTerrainCheck.run', () {
    test('a point over land (seafloor at or above the waterline)', () {
      final grid = _flatGrid(depth: -1);
      final result = NavTrackTerrainCheck.run(
        [_point(depth: 5)],
        _anchor,
        grid,
      );
      expect(result.classifications, [NavTrackTerrainClass.onLand]);
      expect(result.onLandCount, 1);
      expect(result.belowSeafloorCount, 0);
      expect(result.unknownCount, 0);
    });

    test('a point over nodata is unknown', () {
      final grid = BathymetryGrid(
        originLat: _anchor.latitude,
        originLon: _anchor.longitude,
        cellSizeLatDeg: 0.01,
        cellSizeLonDeg: 0.01,
        rows: 3,
        cols: 3,
        depthsMeters: List<double?>.filled(9, null),
        sourceId: 'test',
        resolutionMeters: 10,
        fetchedAt: DateTime(2026, 1, 1),
      );
      final result = NavTrackTerrainCheck.run(
        [_point(depth: 5)],
        _anchor,
        grid,
      );
      expect(result.classifications, [NavTrackTerrainClass.unknown]);
      expect(result.unknownCount, 1);
    });

    test('a point outside the grid is unknown', () {
      final grid = _flatGrid(depth: 20, cellSizeDeg: 0.001);
      // 1 degree of longitude is far outside a 3x3 grid of 0.001-degree cells.
      final result = NavTrackTerrainCheck.run(
        [_point(east: 100000, depth: 5)],
        _anchor,
        grid,
      );
      expect(result.classifications, [NavTrackTerrainClass.unknown]);
    });

    test('a point just inside the tolerance is ok', () {
      final grid = _flatGrid(depth: 10, resolutionMeters: 10);
      // tolerance = max(2, 0.15*10) = 2; 10 + 1.9 is within tolerance.
      final result = NavTrackTerrainCheck.run(
        [_point(depth: 11.9)],
        _anchor,
        grid,
      );
      expect(result.classifications, [NavTrackTerrainClass.ok]);
      expect(result.belowSeafloorCount, 0);
    });

    test('a point clearly below the seafloor', () {
      final grid = _flatGrid(depth: 10, resolutionMeters: 10);
      // tolerance = 2; route depth 15 exceeds seafloor 10 by 5.
      final result = NavTrackTerrainCheck.run(
        [_point(depth: 15)],
        _anchor,
        grid,
      );
      expect(result.classifications, [NavTrackTerrainClass.belowSeafloor]);
      expect(result.belowSeafloorCount, 1);
      expect(result.maxPenetrationMeters, closeTo(5, 1e-9));
    });

    test(
      'tolerance scales with resolution: same depths, coarser grid tolerates more',
      () {
        final fineGrid = _flatGrid(depth: 10, resolutionMeters: 10); // tol = 2
        // 90 m stays under the coarse cutoff, so this still exercises the
        // tolerance itself rather than the coarse-grid skip.
        final coarseGrid = _flatGrid(
          depth: 10,
          resolutionMeters: 90,
        ); // tol = 13.5

        final fine = NavTrackTerrainCheck.run(
          [_point(depth: 16)],
          _anchor,
          fineGrid,
        );
        final coarse = NavTrackTerrainCheck.run(
          [_point(depth: 16)],
          _anchor,
          coarseGrid,
        );

        expect(fine.classifications, [NavTrackTerrainClass.belowSeafloor]);
        expect(coarse.classifications, [NavTrackTerrainClass.ok]);
      },
    );

    test(
      'a coarse grid (>=100m) flags the below-seafloor check as not meaningful',
      () {
        final coarseGrid = _flatGrid(depth: 10, resolutionMeters: 115);
        final result = NavTrackTerrainCheck.run(
          [_point(depth: 5)],
          _anchor,
          coarseGrid,
        );
        expect(result.resolutionSupportsBelowSeafloorCheck, isFalse);
      },
    );

    test(
      'a coarse grid does not flag below-seafloor points, only land conflicts',
      () {
        final coarseGrid = _flatGrid(depth: 10, resolutionMeters: 115);
        final result = NavTrackTerrainCheck.run(
          [_point(depth: 200)],
          _anchor,
          coarseGrid,
        );
        expect(result.classifications, [NavTrackTerrainClass.ok]);
        expect(result.belowSeafloorCount, 0);
        expect(result.maxPenetrationMeters, 0);
        expect(result.conflictingIndices, isEmpty);
      },
    );

    test('a coarse grid still flags points over land', () {
      final coarseGrid = _flatGrid(depth: -1, resolutionMeters: 115);
      final result = NavTrackTerrainCheck.run(
        [_point(depth: 5)],
        _anchor,
        coarseGrid,
      );
      expect(result.classifications, [NavTrackTerrainClass.onLand]);
      expect(result.conflictingIndices, [0]);
    });

    test('a fine grid (<100m) supports the below-seafloor check', () {
      final fineGrid = _flatGrid(depth: 10, resolutionMeters: 10);
      final result = NavTrackTerrainCheck.run(
        [_point(depth: 5)],
        _anchor,
        fineGrid,
      );
      expect(result.resolutionSupportsBelowSeafloorCheck, isTrue);
    });

    test('summary counts across a mixed route', () {
      final grid = _flatGrid(depth: 10, resolutionMeters: 10);
      final points = [
        _point(depth: 5), // ok
        _point(depth: 20), // below seafloor, penetration 10
        _point(depth: 25), // below seafloor, penetration 15
      ];
      final result = NavTrackTerrainCheck.run(points, _anchor, grid);
      expect(result.total, 3);
      expect(result.okCount, 1);
      expect(result.belowSeafloorCount, 2);
      expect(result.maxPenetrationMeters, closeTo(15, 1e-9));
      expect(result.conflictingIndices, [1, 2]);
    });

    test('empty route', () {
      final grid = _flatGrid(depth: 10);
      final result = NavTrackTerrainCheck.run(const [], _anchor, grid);
      expect(result.total, 0);
      expect(result.classifications, isEmpty);
      expect(result.maxPenetrationMeters, 0);
    });
  });
}
