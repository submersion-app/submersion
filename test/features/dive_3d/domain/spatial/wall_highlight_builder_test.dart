import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/wall_highlight_builder.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('wallCellSlopeDegrees', () {
    test('north-sloping cell: 50 m drop over 100 m is 26.57 degrees', () {
      // dNorth = ((nw + ne) - (sw + se)) / 2 / 100 = ((60+60)-(10+10))/2/100
      //        = 0.5; dEast = 0. angle = atan(0.5) = 26.565 degrees.
      final angle = wallCellSlopeDegrees(
        sw: 10,
        se: 10,
        nw: 60,
        ne: 60,
        eastSpacingMeters: 100,
        northSpacingMeters: 100,
      );
      expect(angle, isNotNull);
      expect(angle!, closeTo(26.565, 0.01));
    });

    test('east-sloping cell uses the east axis', () {
      // dEast = ((se + ne) - (sw + nw)) / 2 / 100 = ((30+30)-(10+10))/2/100
      //       = 0.2; dNorth = 0. angle = atan(0.2) = 11.31 degrees.
      final angle = wallCellSlopeDegrees(
        sw: 10,
        se: 30,
        nw: 10,
        ne: 30,
        eastSpacingMeters: 100,
        northSpacingMeters: 100,
      );
      expect(angle!, closeTo(11.31, 0.01));
    });

    test('null or land corner disqualifies the cell', () {
      expect(
        wallCellSlopeDegrees(
          sw: null,
          se: 10,
          nw: 60,
          ne: 60,
          eastSpacingMeters: 100,
          northSpacingMeters: 100,
        ),
        isNull,
      );
      expect(
        wallCellSlopeDegrees(
          sw: -3,
          se: 10,
          nw: 60,
          ne: 60,
          eastSpacingMeters: 100,
          northSpacingMeters: 100,
        ),
        isNull,
      );
    });
  });

  group('buildWallHighlightMesh', () {
    BathymetryGrid gridOf(List<List<double?>> rowsSouthToNorth) {
      final rows = rowsSouthToNorth.length;
      final cols = rowsSouthToNorth.first.length;
      return BathymetryGrid(
        originLat: 0,
        originLon: 0,
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

    SpatialProjection projFor(BathymetryGrid grid) => SpatialProjection(
      minEast: 0,
      maxEast: 100.0 * (grid.cols - 1),
      minNorth: 0,
      maxNorth: 100.0 * (grid.rows - 1),
      maxDepth: grid.maxDepthMeters,
    );

    test('one steep cell yields one lifted quad, threshold gates it', () {
      // Left cell slopes 10 -> 60 north (26.57 deg); right cell mixes
      // 10/10/60/10 corners: dEast -0.25, dNorth 0.25, magnitude 0.3536,
      // atan = 19.47 degrees, under 22: only the LEFT cell qualifies.
      final grid = gridOf([
        [10.0, 10.0, 10.0],
        [60.0, 60.0, 10.0],
      ]);
      final proj = projFor(grid);
      final mesh = buildWallHighlightMesh(
        grid: grid,
        center: const GeoPoint(0, 0),
        projection: proj,
        thresholdDeg: 22,
      );
      expect(mesh, isNotNull);
      expect(mesh!.vertexCount, 4);
      expect(mesh.indices, hasLength(6));
      expect(mesh.opacity, closeTo(0.45, 1e-9));
      // Vertices ride the terrain surface plus a small lift: the sw corner
      // sits at yOf(10) + 0.015.
      expect(mesh.positions[1], closeTo(proj.yOf(10) + 0.015, 1e-5));

      expect(
        buildWallHighlightMesh(
          grid: grid,
          center: const GeoPoint(0, 0),
          projection: proj,
          thresholdDeg: 30,
        ),
        isNull,
      );
    });
  });
}
