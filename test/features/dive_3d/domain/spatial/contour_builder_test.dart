import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('resolvedContourLevels auto mode', () {
    test('meters diver, 35 m site: 5 m steps, majors every 5th', () {
      // span = 35 display units; niceStep(35 / 15) = niceStep(2.33) = 5.
      // Levels: 5,10,15,20,25,30,35 (7 levels). Major at k % 5 == 0: 25.
      final levels = resolvedContourLevels(
        maxDepthMeters: 35,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(),
      );
      expect(levels.map((l) => l.depthMeters).toList(), [
        5,
        10,
        15,
        20,
        25,
        30,
        35,
      ]);
      expect(levels.map((l) => l.isMajor).toList(), [
        false,
        false,
        false,
        false,
        true,
        false,
        false,
      ]);
      expect(levels.first.label, '5 m');
      expect(levels.every((l) => l.colorArgb == null), isTrue);
    });

    test('feet diver, 35 m site: nice steps in feet, meters underneath', () {
      // 35 m = 114.83 ft; niceStep(114.83 / 15) = niceStep(7.66) = 10 ft.
      // Levels 10..110 ft (11 levels), majors at 50 and 100 ft.
      final levels = resolvedContourLevels(
        maxDepthMeters: 35,
        displayUnitInMeters: 0.3048,
        depthSymbol: 'ft',
        appearance: const SeascapeAppearance(),
      );
      expect(levels, hasLength(11));
      expect(levels.first.depthMeters, closeTo(3.048, 1e-9));
      expect(levels.first.label, '10 ft');
      expect(levels[4].isMajor, isTrue); // 50 ft
      expect(levels[9].isMajor, isTrue); // 100 ft
    });

    test('flat-site guard: fewer than 2 fitting levels means none', () {
      // The step has a floor of 1 display unit (no centimeter contours), so
      // span 1.9 m at unit 1.0: step = max(niceStep(1.9/15), 1) = 1;
      // count = floor(1.9 / 1) = 1 < 2: guard fires, no contours.
      expect(
        resolvedContourLevels(
          maxDepthMeters: 1.9,
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
          appearance: const SeascapeAppearance(),
        ),
        isEmpty,
      );
      expect(
        resolvedContourLevels(
          maxDepthMeters: 0,
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
          appearance: const SeascapeAppearance(),
        ),
        isEmpty,
      );
      // span 2.5 m: step 1, levels 1 m and 2 m: just past the guard.
      expect(
        resolvedContourLevels(
          maxDepthMeters: 2.5,
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
          appearance: const SeascapeAppearance(),
        ).map((l) => l.depthMeters).toList(),
        [1.0, 2.0],
      );
    });
  });

  group('resolvedContourLevels custom mode', () {
    test('custom levels sorted, all labeled major, colors carried', () {
      final levels = resolvedContourLevels(
        maxDepthMeters: 50,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
          customLevels: [
            SeascapeContourLevel(depthMeters: 20.0, colorArgb: 0xFF10B981),
            SeascapeContourLevel(depthMeters: 10.0),
          ],
        ),
      );
      expect(levels.map((l) => l.depthMeters).toList(), [10.0, 20.0]);
      expect(levels.every((l) => l.isMajor), isTrue);
      expect(levels[1].colorArgb, 0xFF10B981);
      expect(levels[0].label, '10 m');
    });

    test('empty custom list falls back to auto', () {
      final levels = resolvedContourLevels(
        maxDepthMeters: 35,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
        ),
      );
      expect(levels, hasLength(7)); // same as the auto 35 m case
    });

    test('custom level deeper than terrain is kept (yields no line later)', () {
      final levels = resolvedContourLevels(
        maxDepthMeters: 15,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
          customLevels: [SeascapeContourLevel(depthMeters: 40.0)],
        ),
      );
      expect(levels.single.depthMeters, 40.0);
    });
  });

  group('marchGrid', () {
    double eastOf(int c) => c * 100.0;
    double northOf(int r) => r * 100.0;

    test('single cell, vertical isobath at the midpoint', () {
      // Corners: sw=5 se=15 nw=5 ne=15, level 10. Inside (>=10) = se+ne,
      // marching-squares case S-N: crossings at S edge t=(10-5)/(15-5)=0.5
      // -> (50, 0), and N edge t=0.5 -> (50, 100).
      final grid = [
        [5.0, 15.0], // r=0 (south)
        [5.0, 15.0], // r=1 (north)
      ];
      final lines = marchGrid(
        rows: 2,
        cols: 2,
        depthAt: (r, c) => grid[r][c],
        eastOf: eastOf,
        northOf: northOf,
        levelMeters: 10,
      );
      expect(lines, hasLength(1));
      final pts = lines.single.pointsEastNorth;
      expect(pts, hasLength(4));
      // Accept either direction along the line.
      final ends = {(pts[0], pts[1]), (pts[2], pts[3])};
      expect(ends, {(50.0, 0.0), (50.0, 100.0)});
    });

    test('segments across neighboring cells join into one polyline', () {
      // 2 rows x 3 cols: south row all 5, north row all 15, level 10.
      // Each cell crosses W (t=0.5) and E (t=0.5): a horizontal line at
      // north=50 spanning east 0..200, joined into a single 3-point line.
      final grid = [
        [5.0, 5.0, 5.0],
        [15.0, 15.0, 15.0],
      ];
      final lines = marchGrid(
        rows: 2,
        cols: 3,
        depthAt: (r, c) => grid[r][c],
        eastOf: eastOf,
        northOf: northOf,
        levelMeters: 10,
      );
      expect(lines, hasLength(1));
      final pts = lines.single.pointsEastNorth;
      expect(pts, hasLength(6));
      expect(pts[1], 50.0);
      expect(pts[3], 50.0);
      expect(pts[5], 50.0);
      final easts = {pts[0], pts[2], pts[4]};
      expect(easts, {0.0, 100.0, 200.0});
    });

    test('cells touching a null or land corner are skipped', () {
      // Same as the joining test, but the NE corner is null: the right cell
      // must be skipped, leaving only the left cell's segment.
      final grid = <List<double?>>[
        [5.0, 5.0, 5.0],
        [15.0, 15.0, null],
      ];
      final lines = marchGrid(
        rows: 2,
        cols: 3,
        depthAt: (r, c) => grid[r][c],
        eastOf: eastOf,
        northOf: northOf,
        levelMeters: 10,
      );
      expect(lines, hasLength(1));
      expect(lines.single.pointsEastNorth, hasLength(4));
      // Land corners (depth <= 0) are skipped the same way.
      final landGrid = [
        [5.0, -2.0],
        [15.0, 15.0],
      ];
      expect(
        marchGrid(
          rows: 2,
          cols: 2,
          depthAt: (r, c) => landGrid[r][c],
          eastOf: eastOf,
          northOf: northOf,
          levelMeters: 10,
        ),
        isEmpty,
      );
    });

    test('level outside the cell range yields nothing', () {
      final grid = [
        [5.0, 6.0],
        [7.0, 8.0],
      ];
      expect(
        marchGrid(
          rows: 2,
          cols: 2,
          depthAt: (r, c) => grid[r][c],
          eastOf: eastOf,
          northOf: northOf,
          levelMeters: 40,
        ),
        isEmpty,
      );
    });
  });

  group('buildContourLayers', () {
    BathymetryGrid gridOf(List<List<double?>> rowsSouthToNorth) {
      final rows = rowsSouthToNorth.length;
      final cols = rowsSouthToNorth.first.length;
      return BathymetryGrid(
        originLat: 0,
        originLon: 0,
        // ~0.0009 deg lat is ~100 m; longitude at lat 0 is ~111320 m/deg.
        cellSizeLatDeg: 100.0 / 110540.0,
        cellSizeLonDeg: 100.0 / 111320.0,
        rows: rows,
        cols: cols,
        depthsMeters: [for (final r in rowsSouthToNorth) ...r],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 15),
      );
    }

    const center = GeoPoint(0, 0);

    SpatialProjection projFor(BathymetryGrid grid) {
      // Mirror the geometry services: the grid box frames the scene.
      return SpatialProjection(
        minEast: 0,
        maxEast: 100.0 * (grid.cols - 1),
        minNorth: 0,
        maxNorth: 100.0 * (grid.rows - 1),
        maxDepth: grid.maxDepthMeters,
      );
    }

    test('produces overlay-gated layers and major labels', () {
      // Auto levels 5..45 (step 5, major at 25). Level 5 yields NO line:
      // every corner is >= 5, so both cells are case 15 (all inside). The
      // other 8 levels each cross exactly one cell row: with inside = ">=",
      // level 25 crosses only the south cell (t = 1 at the shared edge) and
      // level 45 crosses the north cell at its top edge. 8 layers total:
      // 10,15,20,25,30,35,40,45.
      final grid = gridOf([
        [5.0, 5.0, 5.0],
        [25.0, 25.0, 25.0],
        [45.0, 45.0, 45.0],
      ]);
      final result = buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      expect(result.layers, hasLength(8));
      expect(
        result.layers.every((l) => l.overlay == SceneOverlay.contours),
        isTrue,
      );
      // One labeled level (25 m major) with 5 anchor triplets.
      expect(result.labels, hasLength(1));
      expect(result.labels.single.text, '25 m');
      expect(result.labels.single.anchorsXyz.length, 15);
      // Anchors ride the contour's scene height: yOf(25) plus lifts.
      final y = projFor(grid).yOf(25);
      expect(result.labels.single.anchorsXyz[1], closeTo(y + 0.08, 1e-6));
    });

    test('major contour ribbons are wider than minors', () {
      final grid = gridOf([
        [5.0, 5.0, 5.0],
        [25.0, 25.0, 25.0],
        [45.0, 45.0, 45.0],
      ]);
      final result = buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      double widthOf(SceneLayer layer) {
        // Ribbon vertices come in left/right pairs; the first pair's
        // separation is the full ribbon width in scene units.
        final p = layer.mesh.positions;
        final dx = p[3] - p[0], dz = p[5] - p[2];
        return math.sqrt(dx * dx + dz * dz);
      }

      // Rendered levels are 10,15,20,25,...: the 25 m major is index 3.
      expect(widthOf(result.layers[3]), greaterThan(widthOf(result.layers[0])));
    });

    test('custom level color overrides the ink', () {
      final grid = gridOf([
        [5.0, 5.0],
        [45.0, 45.0],
      ]);
      final result = buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
          customLevels: [
            SeascapeContourLevel(depthMeters: 20.0, colorArgb: 0xFF10B981),
          ],
        ),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      expect(result.layers, hasLength(1));
      // 0xFF10B981: r = 0x10/255, per-vertex float colors.
      expect(result.layers.single.mesh.colors[0], closeTo(0x10 / 255, 1e-4));
      // Custom levels are all labeled.
      expect(result.labels.single.text, '20 m');
    });

    test('empty result for a flat or too-shallow grid', () {
      final grid = gridOf([
        [1.0, 1.0],
        [1.2, 1.2],
      ]);
      final result = buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      expect(result.layers, isEmpty);
      expect(result.labels, isEmpty);
    });
  });
}
