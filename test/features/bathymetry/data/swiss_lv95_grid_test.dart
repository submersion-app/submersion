import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/lv95_transform.dart';
import 'package:submersion/features/bathymetry/data/sources/esri_ascii_parser.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lv95_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';

void main() {
  final body = File(
    'test/fixtures/bathymetry/swissbathy3d_sample.asc',
  ).readAsStringSync();
  final when = DateTime.utc(2026, 8, 30);

  group('parseSwissLv95Grid', () {
    test(
      'reprojects LV95 meters to WGS84 degrees and applies the lake level',
      () {
        final grid = parseSwissLv95Grid(
          body,
          sourceId: 'swissbathy3d',
          fetchedAt: when,
          referenceLevelMeters: 406.1, // Zürichsee
        );

        expect(grid.rows, 4);
        expect(grid.cols, 4);
        expect(grid.sourceId, 'swissbathy3d');
        expect(grid.resolutionMeters, 100);

        // The origin must be plausible WGS84 degrees, not raw LV95 meters.
        expect(grid.originLat, inInclusiveRange(45.0, 48.0));
        expect(grid.originLon, inInclusiveRange(5.0, 11.0));

        // Cross-check the origin against a direct LV95 -> WGS84 conversion
        // of the same cell-center corner (xllcorner+cellsize/2, ...).
        final expectedOrigin = Lv95Transform.toWgs84(2685050, 1240050);
        expect(grid.originLat, closeTo(expectedOrigin.latitude, 1e-9));
        expect(grid.originLon, closeTo(expectedOrigin.longitude, 1e-9));

        // Southernmost data line (408.0 409.0 410.0 411.0) is grid row 0:
        // depth = 406.1 - 408.0 = -1.9.
        expect(grid.depthAt(0, 0), closeTo(-1.9, 1e-9));
        // Northernmost data line (400.0 399.0 398.0 397.0) is grid row 3:
        // depth = 406.1 - 400.0 = 6.1.
        expect(grid.depthAt(3, 0), closeTo(6.1, 1e-9));
        // nodata sentinel stays null.
        expect(grid.depthAt(1, 1), isNull);
      },
    );

    test('the latitude cell size shares the terrain builder\'s meters-per-'
        'degree constant, not an independent approximation', () {
      // Bug: an independently chosen conversion constant here (even one
      // off by under 1%) makes the grid's own idea of "how far apart are
      // my rows" disagree with how BathymetryTerrainBuilder later turns
      // those rows back into scene meters -- silently shifting a stitched
      // mosaic's true-world footprint away from where the 3D scene places
      // the dive site marker (always at the exact query coordinate).
      final grid = parseSwissLv95Grid(
        body,
        sourceId: 'swissbathy3d',
        fetchedAt: when,
        referenceLevelMeters: 406.1,
      );
      expect(
        grid.cellSizeLatDeg,
        closeTo(100.0 / BathymetryTerrainBuilder.metersPerDegLat, 1e-15),
      );
      expect(BathymetryTerrainBuilder.metersPerDegLat, metersPerDegreeLatitude);
    });

    test('a shore cell above the lake level becomes a negative depth', () {
      const aboveLakeLevel = '''
ncols 1
nrows 1
xllcorner 2685000
yllcorner 1240000
cellsize 100
nodata_value -9999
410.0
''';
      final grid = parseSwissLv95Grid(
        aboveLakeLevel,
        sourceId: 'swissbathy3d',
        fetchedAt: when,
        referenceLevelMeters: 406.1,
      );
      expect(grid.depthAt(0, 0), closeTo(406.1 - 410.0, 1e-9));
      expect(grid.depthAt(0, 0), lessThan(0));
    });
  });

  group('extractRawEsriSubgrid', () {
    // Regression tests for Bug 13: a live STAC check found a single
    // swissBATHY3D asset can cover an entire lake rather than one 1-km
    // tile, so every tile coordinate within a lake resolved to the same
    // asset and (before this function existed) cached that whole grid
    // verbatim -- identical content regardless of which tile was actually
    // requested. This slices out just the cells belonging to a requested
    // tile's own LV95 bounding box.
    RawEsriGrid wideRaw() {
      // Three adjacent 1-km-wide (10 cells @ 100 m) columns of tiles, each
      // with its own distinct, easily distinguishable value.
      const cellsPerTile = 10;
      String row(double value) => List.filled(cellsPerTile, value).join(' ');
      final buffer = StringBuffer()
        ..writeln('ncols ${cellsPerTile * 3}')
        ..writeln('nrows $cellsPerTile')
        ..writeln('xllcorner 2685000')
        ..writeln('yllcorner 1240000')
        ..writeln('cellsize 100')
        ..writeln('nodata_value -9999');
      final dataRow = '${row(100.0)} ${row(150.0)} ${row(200.0)}';
      for (var r = 0; r < cellsPerTile; r++) {
        buffer.writeln(dataRow);
      }
      return EsriAsciiGridParser.parseRaw(buffer.toString());
    }

    test('extracts only the requested tile\'s own cells, not its neighbors '
        'or the whole asset', () {
      final raw = wideRaw();

      final west = extractRawEsriSubgrid(
        raw,
        minEasting: 2685000,
        maxEasting: 2686000,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      )!;
      final east = extractRawEsriSubgrid(
        raw,
        minEasting: 2687000,
        maxEasting: 2688000,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      )!;

      expect(west.ncols, 10);
      expect(west.nrows, 10);
      expect(west.values, everyElement(100.0));
      expect(east.ncols, 10);
      expect(east.nrows, 10);
      expect(east.values, everyElement(200.0));

      // The two tiles are far apart in the source asset and must not share
      // any content -- the exact Bug 13 symptom this guards against.
      expect(west.values, isNot(east.values));
    });

    test(
      'the extracted subgrid\'s origin shifts to the tile\'s own corner',
      () {
        final raw = wideRaw();
        final middle = extractRawEsriSubgrid(
          raw,
          minEasting: 2686000,
          maxEasting: 2687000,
          minNorthing: 1240000,
          maxNorthing: 1241000,
        )!;
        expect(middle.xll, 2686000);
        expect(middle.yll, 1240000);
        expect(middle.values, everyElement(150.0));
      },
    );

    test('a box entirely outside the source asset returns null, a genuine '
        'gap rather than fabricated data', () {
      final raw = wideRaw();
      final outside = extractRawEsriSubgrid(
        raw,
        minEasting: 2695000,
        maxEasting: 2696000,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      );
      expect(outside, isNull);
    });

    test('a box only partially overlapping the source asset is clamped to '
        'the available cells', () {
      final raw = wideRaw();
      final clipped = extractRawEsriSubgrid(
        raw,
        minEasting: 2684500, // 500 m before the asset starts
        maxEasting: 2685500,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      )!;
      // Only the [2685000, 2685500) half actually overlaps the asset.
      expect(clipped.ncols, 5);
      expect(clipped.values, everyElement(100.0));
    });
  });

  group('extractRawEsriSubgridFromGrids', () {
    // Regression tests for Bug 15: a live check found a swissBATHY3D zip's
    // own .asc/.grd entries are not guaranteed to be a single whole-lake
    // grid either -- the archive can hold several separate ~1-km entries
    // (swisstopo's own internal sub-tiling). Reading only the zip's first
    // entry meant every requested tile outside that one entry's own
    // footprint came back as a false "no data" gap, except the one
    // coincidentally aligned with it.
    RawEsriGrid subTile(double xll, double yll, double value) {
      const cellsPerTile = 10;
      String row(double v) => List.filled(cellsPerTile, v).join(' ');
      final buffer = StringBuffer()
        ..writeln('ncols $cellsPerTile')
        ..writeln('nrows $cellsPerTile')
        ..writeln('xllcorner $xll')
        ..writeln('yllcorner $yll')
        ..writeln('cellsize 100')
        ..writeln('nodata_value -9999');
      for (var r = 0; r < cellsPerTile; r++) {
        buffer.writeln(row(value));
      }
      return EsriAsciiGridParser.parseRaw(buffer.toString());
    }

    test('picks the one internal entry whose own header actually covers the '
        'requested tile, not just the first entry in the list', () {
      // Two internal sub-tiles, distinct and far enough apart that a
      // fixed-first-entry bug could never accidentally pass this test.
      final west = subTile(2685000, 1240000, 111.0);
      final east = subTile(2695000, 1240000, 222.0);

      final resultForWest = extractRawEsriSubgridFromGrids(
        [west, east], // first entry happens to be the match
        minEasting: 2685000,
        maxEasting: 2686000,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      )!;
      expect(resultForWest.values, everyElement(111.0));

      final resultForEast = extractRawEsriSubgridFromGrids(
        [west, east], // first entry is NOT the match this time
        minEasting: 2695000,
        maxEasting: 2696000,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      )!;
      expect(resultForEast.values, everyElement(222.0));

      // The exact Bug 15 symptom: two distinct requested locations must
      // not resolve to the same content just because they share a zip.
      expect(resultForWest.values, isNot(resultForEast.values));
    });

    test('stitches two internal entries together when the requested tile '
        'straddles both', () {
      final west = subTile(2685000, 1240000, 111.0);
      final east = subTile(2686000, 1240000, 222.0);

      final straddling = extractRawEsriSubgridFromGrids(
        [west, east],
        minEasting: 2685500,
        maxEasting: 2686500,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      )!;

      expect(straddling.ncols, 10); // 500m of each side, at 100m cells
      expect(straddling.values.take(5), everyElement(111.0));
      expect(straddling.values.skip(5).take(5), everyElement(222.0));
    });

    test('returns null when no internal entry overlaps the requested tile at '
        'all', () {
      final west = subTile(2685000, 1240000, 111.0);
      final east = subTile(2695000, 1240000, 222.0);

      final result = extractRawEsriSubgridFromGrids(
        [west, east],
        minEasting: 2690000,
        maxEasting: 2691000,
        minNorthing: 1240000,
        maxNorthing: 1241000,
      );
      expect(result, isNull);
    });

    test('an empty grid list returns null', () {
      expect(
        extractRawEsriSubgridFromGrids(
          const [],
          minEasting: 2685000,
          maxEasting: 2686000,
          minNorthing: 1240000,
          maxNorthing: 1241000,
        ),
        isNull,
      );
    });
  });
}
