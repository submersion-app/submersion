import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/utils/lv95_transform.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_stac_client.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

Uint8List _zipOf(String entryName, String content) {
  final archive = Archive();
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Like [_zipOf], but with several `.asc` entries in one zip -- the shape
/// a live check found swissBATHY3D's own asset zips can actually have
/// (Bug 15): several internal sub-tile grids rather than a single
/// whole-lake or single-tile one.
Uint8List _zipOfMultiple(Map<String, String> entries) {
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in entries.entries) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Echoes the request's own `bbox` query parameter back as the mocked STAC
/// feature's `bbox`, so these fixtures satisfy [SwissStacClient]'s overlap
/// check the same way a real, spatially-honest server response would.
List<double> _requestedBbox(http.Request req) =>
    req.url.queryParameters['bbox']!.split(',').map(double.parse).toList();

void main() {
  final gridBody = File(
    'test/fixtures/bathymetry/swissbathy3d_sample.asc',
  ).readAsStringSync();
  // The fixture's own tile center (xllcorner/yllcorner 2685000/1240000,
  // cellsize 100 in swissbathy3d_sample.asc -> tile 2685_1240), and still
  // inside Zürichsee's bounding box (see swiss_lake_levels.dart). Tile
  // position used not to matter here -- any point inside the lake's bbox
  // sufficed while fetch() returned the whole downloaded grid regardless of
  // where it was requested (the Bug 13 symptom); now that
  // extractRawEsriSubgrid enforces real LV95 overlap, this must resolve to
  // the fixture's actual tile or every fetch below would find no overlap.
  final zurichseeTileCenter = Lv95Transform.toWgs84(2685500, 1240500);
  final zurichseePoint = GeoPoint(
    zurichseeTileCenter.latitude,
    zurichseeTileCenter.longitude,
  );
  const alpsPoint = GeoPoint(46.55, 7.98); // not near any listed lake

  late LocalCacheDatabase db;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  SwissBathy3dSource buildSource(
    Future<http.Response> Function(http.Request) handler,
  ) => SwissBathy3dSource(
    tileCache: SwissBathyTileCacheRepository(db),
    stacClient: SwissStacClient(client: MockClient(handler)),
  );

  group('SwissBathy3dSource.covers', () {
    test('true inside a known lake bounding box', () {
      final source = buildSource((_) async => http.Response('', 404));
      expect(source.covers(zurichseePoint), isTrue);
    });

    test('false outside every known lake', () {
      final source = buildSource((_) async => http.Response('', 404));
      expect(source.covers(alpsPoint), isFalse);
    });
  });

  group('SwissBathy3dSource.fetch', () {
    test('throws without any HTTP call outside known lakes', () async {
      var calls = 0;
      final source = buildSource((_) async {
        calls++;
        return http.Response('', 404);
      });
      expect(
        () => source.fetch(alpsPoint, spanMeters: 1000),
        throwsA(isA<BathymetryFetchException>()),
      );
      expect(calls, 0);
    });

    test(
      'downloads, unzips, reprojects and caches the tile on first fetch',
      () async {
        var itemCalls = 0;
        var downloadCalls = 0;
        final source = buildSource((req) async {
          if (req.url.path.endsWith('/items')) {
            itemCalls++;
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': _requestedBbox(req),
                    'assets': {
                      'grid': {'href': 'https://example.org/tile_grid.zip'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          downloadCalls++;
          return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
        });

        // A span well under a tile width keeps this to the single tile
        // under zurichseePoint; multi-tile stitching has its own tests
        // below.
        final grid = await source.fetch(zurichseePoint, spanMeters: 100);
        expect(grid.sourceId, 'swissbathy3d');
        expect(grid.rows, 4);
        expect(itemCalls, 1);
        expect(downloadCalls, 1);

        // Second fetch of a coordinate in the same tile must hit neither
        // the STAC API nor the download endpoint again (tile-level cache).
        final again = await source.fetch(zurichseePoint, spanMeters: 100);
        expect(again.sourceId, 'swissbathy3d');
        expect(itemCalls, 1);
        expect(downloadCalls, 1);
      },
    );

    test(
      'caches a definitive "no tile" answer and never re-queries it',
      () async {
        var itemCalls = 0;
        final source = buildSource((req) async {
          itemCalls++;
          return http.Response(jsonEncode({'features': []}), 200);
        });

        await expectLater(
          source.fetch(zurichseePoint, spanMeters: 100),
          throwsA(isA<BathymetryFetchException>()),
        );
        expect(itemCalls, 1);

        await expectLater(
          source.fetch(zurichseePoint, spanMeters: 100),
          throwsA(isA<BathymetryFetchException>()),
        );
        // The negative answer was cached by tile key: no second STAC call.
        expect(itemCalls, 1);
      },
    );

    test(
      'a collection-not-found response surfaces as a fetch exception',
      () async {
        final source = buildSource((_) async => http.Response('nope', 404));
        expect(
          () => source.fetch(zurichseePoint, spanMeters: 1000),
          throwsA(isA<BathymetryFetchException>()),
        );
      },
    );

    test(
      'stitches all tiles the requested spanMeters bounding box touches',
      () async {
        // Straddles the LV95 easting=2685000 tile boundary while a wide
        // northing margin keeps it inside a single northing tile (1245), so
        // spanMeters=200 needs exactly two adjacent tiles east-west.
        const boundaryPoint = GeoPoint(47.354865314, 8.563694834);
        // West/east of this longitude tells the two tiles apart from the
        // request's own bbox — bounded-concurrency fetches no longer
        // guarantee which tile's HTTP request lands first, so the mock must
        // route by content, not by call order.
        final boundaryLon = Lv95Transform.toWgs84(2685000, 1245500).longitude;

        const tileAGrid = '''
ncols 2
nrows 2
xllcorner 2684000
yllcorner 1245000
cellsize 500
nodata_value -9999
400.0 400.0
400.0 400.0
''';
        const tileBGrid = '''
ncols 2
nrows 2
xllcorner 2685000
yllcorner 1245000
cellsize 500
nodata_value -9999
410.0 410.0
410.0 -9999
''';

        var itemCalls = 0;
        var downloadCalls = 0;
        final source = buildSource((req) async {
          if (req.url.path.endsWith('/items')) {
            itemCalls++;
            final bbox = _requestedBbox(req);
            final centerLon = (bbox[0] + bbox[2]) / 2;
            final href = centerLon < boundaryLon
                ? 'https://example.org/tile_a.zip'
                : 'https://example.org/tile_b.zip';
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': bbox,
                    'assets': {
                      'grid': {'href': href},
                    },
                  },
                ],
              }),
              200,
            );
          }
          downloadCalls++;
          final body = req.url.path.endsWith('tile_a.zip')
              ? tileAGrid
              : tileBGrid;
          return http.Response.bytes(_zipOf('tile.asc', body), 200);
        });

        final grid = await source.fetch(boundaryPoint, spanMeters: 200);

        expect(itemCalls, 2);
        expect(downloadCalls, 2);
        expect(grid.rows, 2);
        expect(grid.cols, 4);

        // West tile (Z=400 -> depth 6.1) occupies the western columns, east
        // tile (Z=410 -> depth -3.9) the eastern ones: stitched side by
        // side, not overwritten or overlapping.
        expect(grid.depthAt(0, 0), closeTo(405.92 - 400.0, 1e-6));
        expect(grid.depthAt(1, 0), closeTo(405.92 - 400.0, 1e-6));
        expect(grid.depthAt(0, 2), closeTo(405.92 - 410.0, 1e-6));
        expect(grid.depthAt(1, 3), closeTo(405.92 - 410.0, 1e-6));
        // The east tile's nodata sentinel survives stitching as a gap.
        expect(grid.depthAt(0, 3), isNull);
      },
    );

    test('multiple distinct tile coordinates that resolve to the same STAC '
        'asset href download and parse it only once', () async {
      // Regression test for the real Bug 12 symptom, reported via the
      // per-tile diagnostic panel: a fresh install, querying a wide span
      // around a real Walensee dive site, found every one of ~72 distinct
      // 1-km tile coordinates carrying byte-identical raw grid content.
      // The per-tile pipeline itself is stateless and correctly keyed
      // (verified by every other test in this file using genuinely
      // different hrefs per tile), so the only way distinct tile
      // coordinates legitimately end up with identical content is the
      // STAC server resolving them to the very same asset href — this
      // reproduces exactly that server behavior and verifies the fetch
      // still succeeds, still serves each tile its (correctly identical,
      // matching what the server actually said) grid, but stops
      // re-downloading and re-parsing that same zip once per tile
      // coordinate.
      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          return http.Response(
            jsonEncode({
              'features': [
                {
                  // A real STAC item's own bbox can legitimately be wider
                  // than the 1-km tile bbox that was queried -- as long
                  // as it still overlaps every one of this fetch's tile
                  // queries, SwissStacClient._featureOverlaps accepts it
                  // for each of them, exactly like a genuinely
                  // lake-scale (not 1-km-scale) asset would.
                  'bbox': [8.0, 46.0, 10.0, 48.0],
                  'assets': {
                    'grid': {'href': 'https://example.org/shared_tile.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      final grid = await source.fetch(zurichseePoint, spanMeters: 2500);

      expect(
        itemCalls,
        greaterThan(1),
      ); // each tile still resolves its own asset
      expect(downloadCalls, 1); // but the shared href is fetched once
      expect(grid.sourceId, 'swissbathy3d');
    });

    test(
      'a single lake-wide asset is sliced per tile instead of caching the '
      'exact same whole-lake content under every tile it spans (Bug 13)',
      () async {
        // Regression test for the real Bug 13 symptom: a live STAC check
        // found swissBATHY3D publishes one asset per LAKE, not per 1-km
        // tile (already established by the Bug 12 fix's shared-href
        // dedup) -- e.g. all of Walensee in a single
        // "swissbathy3d_walensee" zip. Without slicing that shared raw
        // grid per tile, every tile coordinate within the lake cached and
        // returned the exact same whole-lake content regardless of its
        // own coordinates, which is why distant, genuinely different dive
        // sites on the same lake rendered identical meshes.
        //
        // The mocked asset spans three adjacent tiles with distinct,
        // tile-specific values; fetching the west and east tiles must
        // each recover only their own tile-sized slice, not the whole
        // three-tile asset and not each other's content.
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
        final wideGrid = buffer.toString();

        var downloadCalls = 0;
        final source = buildSource((req) async {
          if (req.url.path.endsWith('/items')) {
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    // Wide enough to overlap every tile bbox this test
                    // queries -- mirrors a genuinely lake-scale asset.
                    'bbox': [8.0, 46.0, 10.0, 48.0],
                    'assets': {
                      'grid': {'href': 'https://example.org/lake_wide.zip'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          downloadCalls++;
          return http.Response.bytes(_zipOf('lake.asc', wideGrid), 200);
        });

        final west = Lv95Transform.toWgs84(2685500, 1240500); // tile 2685
        final east = Lv95Transform.toWgs84(2687500, 1240500); // tile 2687

        final westGrid = await source.fetch(
          GeoPoint(west.latitude, west.longitude),
          spanMeters: 100,
        );
        final eastGrid = await source.fetch(
          GeoPoint(east.latitude, east.longitude),
          spanMeters: 100,
        );

        // Separate fetch() calls each download their own copy (tile-level
        // caching, not asset-level -- see the dedicated Bug 12 test above
        // for within-one-fetch() sharing); what matters here is content.
        expect(downloadCalls, 2);

        // Each fetch recovered just its own 1-km tile's cells, not the
        // whole three-tile-wide asset.
        expect(westGrid.rows, cellsPerTile);
        expect(westGrid.cols, cellsPerTile);
        expect(eastGrid.rows, cellsPerTile);
        expect(eastGrid.cols, cellsPerTile);

        const referenceLevel = 405.92; // Zürichsee
        expect(westGrid.depthAt(0, 0), closeTo(referenceLevel - 100.0, 1e-9));
        expect(eastGrid.depthAt(0, 0), closeTo(referenceLevel - 200.0, 1e-9));
        // The exact Bug 13 symptom this guards against: two distinct,
        // far-apart tiles must not end up with identical content.
        expect(westGrid.depthAt(0, 0), isNot(eastGrid.depthAt(0, 0)));
      },
    );

    test('a zip asset containing several separate internal sub-tile grids is '
        'searched for the one that actually covers each requested tile, not '
        'just its first entry (Bug 15)', () async {
      // Regression test for the real Bug 15 symptom, reported via the
      // per-tile diagnostic panel after the Bug 13/14 fixes: a live
      // download of the actual swissBATHY3D zip found its own header
      // described only a ~1-km area, not the whole lake the Bug 13 fix
      // assumed a single asset always covered -- yet the STAC item's
      // bbox and the zip's filename both suggested lake-wide coverage.
      // The remaining explanation is that the zip holds several separate
      // `.asc` entries (swisstopo's own internal sub-tiling), and the
      // code only ever read the zip's FIRST matching entry -- so every
      // requested tile outside that one entry's own footprint came back
      // as a false "no data" gap, except the one tile that happened to
      // coincide with it. This mocks exactly that zip shape: three
      // separate `.asc` entries, each covering a different 1-km area
      // with its own distinct value, inside one asset.
      const cellsPerTile = 10;
      String row(double value) => List.filled(cellsPerTile, value).join(' ');
      String tileAsc(double xll, double value) =>
          'ncols $cellsPerTile\n'
          'nrows $cellsPerTile\n'
          'xllcorner $xll\n'
          'yllcorner 1240000\n'
          'cellsize 100\n'
          'nodata_value -9999\n'
          '${List.filled(cellsPerTile, row(value)).join('\n')}\n';

      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  // Wide enough to overlap every tile bbox this test
                  // queries -- mirrors the real STAC item's declared,
                  // lake-scale bbox.
                  'bbox': [8.0, 46.0, 10.0, 48.0],
                  'assets': {
                    'grid': {'href': 'https://example.org/lake_zip.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        return http.Response.bytes(
          _zipOfMultiple({
            // The FIRST entry the zip lists covers tile 2685 only --
            // exactly what a "read only the zip's first entry" bug would
            // return for every one of the three tile requests below.
            'first.asc': tileAsc(2685000, 111.0),
            'second.asc': tileAsc(2687000, 222.0),
            'third.asc': tileAsc(2689000, 333.0),
          }),
          200,
        );
      });

      final first = Lv95Transform.toWgs84(2685500, 1240500); // tile 2685
      final second = Lv95Transform.toWgs84(2687500, 1240500); // tile 2687
      final third = Lv95Transform.toWgs84(2689500, 1240500); // tile 2689

      final firstGrid = await source.fetch(
        GeoPoint(first.latitude, first.longitude),
        spanMeters: 100,
      );
      final secondGrid = await source.fetch(
        GeoPoint(second.latitude, second.longitude),
        spanMeters: 100,
      );
      final thirdGrid = await source.fetch(
        GeoPoint(third.latitude, third.longitude),
        spanMeters: 100,
      );

      // Separate fetch() calls each download their own copy (tile-level
      // caching, not asset-level).
      expect(downloadCalls, 3);

      const referenceLevel = 405.92; // Zürichsee
      expect(firstGrid.depthAt(0, 0), closeTo(referenceLevel - 111.0, 1e-9));
      expect(secondGrid.depthAt(0, 0), closeTo(referenceLevel - 222.0, 1e-9));
      expect(thirdGrid.depthAt(0, 0), closeTo(referenceLevel - 333.0, 1e-9));
      // The exact Bug 15 symptom this guards against: only the entry
      // matching the FIRST tile's own footprint must resolve to it --
      // the second and third tiles must not silently fall back to that
      // same first zip entry's content.
      expect(secondGrid.depthAt(0, 0), isNot(firstGrid.depthAt(0, 0)));
      expect(thirdGrid.depthAt(0, 0), isNot(firstGrid.depthAt(0, 0)));
      expect(secondGrid.depthAt(0, 0), isNot(thirdGrid.depthAt(0, 0)));
    });

    test('falls through to the next STAC candidate when the first one\'s '
        'declared bbox overlaps but its actual downloaded content does not '
        '(Bug 14)', () async {
      // Regression test for the real Bug 14 symptom, reported after the
      // Bug 13 fix: almost every tile in a wide-span fetch came back as
      // "no swissBATHY3D tile here" even though the coordinate was
      // confirmed, by a live STAC check, to sit kilometers inside a
      // lake-wide item's own declared bbox. extractRawEsriSubgrid's row/
      // col math itself checks out against the real coordinates (see the
      // class doc), so the actual defect is one layer up: findAsset()
      // trusted the FIRST feature whose declared bbox merely claimed to
      // overlap, and never checked whether its real, downloaded raster
      // (its own xllcorner/yllcorner/ncols/nrows) covered the tile at
      // all. A declared bbox can be coarser -- or simply wrong -- than
      // the file it labels.
      //
      // Here the STAC response lists two candidates for the requested
      // tile's bbox: the first "claims" to overlap but its real content
      // sits far away (a decoy, like the wrong-tile symptom that inspired
      // Bug 6's bbox check -- except this time the item's own declared
      // bbox is the thing lying, not the server's spatial filter). The
      // second candidate's real content genuinely covers the tile. The
      // fetch must recover the second candidate's data, not treat the
      // first's mismatch as a definitive "no tile here".
      const decoyGrid = '''
ncols 4
nrows 4
xllcorner 2900000
yllcorner 1400000
cellsize 100
nodata_value -9999
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
''';

      var itemCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          final requestedBbox = _requestedBbox(req);
          return http.Response(
            jsonEncode({
              'features': [
                {
                  // Declares overlap with the query, but its real
                  // content (above) sits nowhere near it.
                  'bbox': requestedBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/decoy.zip'},
                  },
                },
                {
                  'bbox': requestedBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/real.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        if (req.url.path.endsWith('decoy.zip')) {
          return http.Response.bytes(_zipOf('tile.asc', decoyGrid), 200);
        }
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      final grid = await source.fetch(zurichseePoint, spanMeters: 100);

      expect(itemCalls, 1);
      expect(grid.sourceId, 'swissbathy3d');
      expect(grid.rows, 4);
      expect(grid.cols, 4);
      const referenceLevel = 405.92; // Zürichsee
      // gridBody's cell (0, 0) resolves to 408.0 once the parser's south-
      // first row flip is applied to the fixture's data lines; what
      // matters here is that it is the fixture's real content, not the
      // decoy's uniform 1.0 everywhere.
      expect(grid.depthAt(0, 0), closeTo(referenceLevel - 408.0, 1e-9));
    });

    test('treats the tile as a genuine gap only once every candidate\'s real '
        'content has been checked and none of them overlap (Bug 14)', () async {
      const decoyGrid = '''
ncols 4
nrows 4
xllcorner 2900000
yllcorner 1400000
cellsize 100
nodata_value -9999
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
''';

      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          final requestedBbox = _requestedBbox(req);
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': requestedBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/decoy1.zip'},
                  },
                },
                {
                  'bbox': requestedBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/decoy2.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        return http.Response.bytes(_zipOf('tile.asc', decoyGrid), 200);
      });

      await expectLater(
        source.fetch(zurichseePoint, spanMeters: 100),
        throwsA(isA<BathymetryFetchException>()),
      );
      // Both candidates' real content was checked before giving up.
      expect(downloadCalls, 2);
    });

    test('the query coordinate stays inside the stitched mosaic\'s rendered '
        'bounds, at realistic tile resolution and tile count', () async {
      // The 3D scene always places the dive site marker at (0,0) in a
      // frame centered on the exact query coordinate (see
      // SiteSeascapeGeometryService._sitePin / BathymetryTerrainBuilder.
      // enuBounds), so the terrain mesh built from a stitched mosaic must
      // actually enclose that coordinate -- otherwise the marker renders
      // outside the mesh it is supposed to sit on.
      final center = zurichseePoint;
      final centerLv95 = Lv95Transform.fromWgs84(
        center.latitude,
        center.longitude,
      );
      final baseTileE = (centerLv95.easting / 1000).floor();
      final baseTileN = (centerLv95.northing / 1000).floor();

      const cellsize = 2.0;
      const cellsPerTile = 500; // swissBATHY3D's real 1 km / 2 m tiling

      String tileGrid(int tileE, int tileN) {
        final row = List.filled(cellsPerTile, '400.0').join(' ');
        final buffer = StringBuffer()
          ..writeln('ncols $cellsPerTile')
          ..writeln('nrows $cellsPerTile')
          ..writeln('xllcorner ${tileE * 1000}')
          ..writeln('yllcorner ${tileN * 1000}')
          ..writeln('cellsize $cellsize')
          ..writeln('nodata_value -9999');
        for (var r = 0; r < cellsPerTile; r++) {
          buffer.writeln(row);
        }
        return buffer.toString();
      }

      final tileKeys = <String>[
        for (var tN = baseTileN - 1; tN <= baseTileN + 1; tN++)
          for (var tE = baseTileE - 1; tE <= baseTileE + 1; tE++) '${tE}_$tN',
      ];
      final tileBodies = {
        for (final key in tileKeys)
          key: tileGrid(
            int.parse(key.split('_')[0]),
            int.parse(key.split('_')[1]),
          ),
      };

      // Bounded-concurrency fetches no longer guarantee which of the nine
      // tiles' HTTP requests lands first, so the mock derives the tile key
      // from the request's own bbox center (inverse of _tileBboxWgs84)
      // instead of assuming a fixed nested-loop call order.
      String keyForRequest(http.Request req) {
        final bbox = _requestedBbox(req);
        final centerLat = (bbox[1] + bbox[3]) / 2;
        final centerLon = (bbox[0] + bbox[2]) / 2;
        final lv95 = Lv95Transform.fromWgs84(centerLat, centerLon);
        final tE = (lv95.easting / 1000).floor();
        final tN = (lv95.northing / 1000).floor();
        return '${tE}_$tN';
      }

      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          final key = keyForRequest(req);
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': _requestedBbox(req),
                  'assets': {
                    'grid': {'href': 'https://example.org/$key.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        final key = req.url.pathSegments.last.replaceAll('.zip', '');
        return http.Response.bytes(_zipOf('tile.asc', tileBodies[key]!), 200);
      });

      final grid = await source.fetch(center, spanMeters: 2500);
      final box = BathymetryTerrainBuilder.enuBounds(grid, center);

      expect(box.minEast, lessThanOrEqualTo(0));
      expect(box.maxEast, greaterThanOrEqualTo(0));
      expect(box.minNorth, lessThanOrEqualTo(0));
      expect(box.maxNorth, greaterThanOrEqualTo(0));
    });

    test('a STAC server that ignores bbox filtering and always answers with an '
        'unrelated tile fails the fetch instead of silently returning a mesh '
        'that does not actually cover the query coordinate', () async {
      // Regression test for the real Bug 6 symptom: the rendered terrain
      // looked like genuine, plausible swissBATHY3D data, but the dive
      // site marker (placed at the exact query coordinate, per
      // BathymetryTerrainBuilder.enuBounds / SiteSeascapeGeometryService)
      // sat far outside it. That can only happen if fetch() returns a
      // grid whose real geographic footprint does not actually contain
      // the query coordinate -- which is exactly what happens if
      // SwissStacClient trusts the server's spatial filtering blindly and
      // the server (bug, unsupported bbox param, or a differently-shaped
      // items response than assumed -- never verified live, see
      // SwissStacClient's class doc) answers every tile lookup with the
      // same unrelated item regardless of the requested bbox.
      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          // A real item, but for a location nowhere near any of the 9x9
          // tiles this fetch actually asked about (its own declared bbox
          // sits far from every requested tile bbox).
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': [8.9, 46.0, 8.91, 46.01],
                  'assets': {
                    'grid': {'href': 'https://example.org/unrelated.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      await expectLater(
        source.fetch(zurichseePoint, spanMeters: 2000),
        throwsA(isA<BathymetryFetchException>()),
      );
      // Every one of the 3x3 requested tiles queried STAC (and each was
      // correctly recognized as not actually answering that tile)...
      expect(itemCalls, 9);
      // ...so the mismatched asset was never downloaded and spliced into
      // the mosaic at all.
      expect(downloadCalls, 0);
    });

    test('a transient failure on one tile does not sink neighboring tiles that '
        'already succeeded', () async {
      // Same boundary point/span as the stitching test above: exactly two
      // tiles. Tile A (west) always succeeds; tile B (east) always returns a
      // server error, simulating the kind of one-off network hiccup that
      // becomes likely once a single site view can span dozens of tiles.
      // Routed by the request's own bbox rather than call order, since
      // bounded-concurrency fetches no longer guarantee which tile's
      // request lands first.
      const boundaryPoint = GeoPoint(47.354865314, 8.563694834);
      final boundaryLon = Lv95Transform.toWgs84(2685000, 1245500).longitude;
      const tileAGrid = '''
ncols 2
nrows 2
xllcorner 2684000
yllcorner 1245000
cellsize 500
nodata_value -9999
400.0 400.0
400.0 400.0
''';

      var itemCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          final bbox = _requestedBbox(req);
          final centerLon = (bbox[0] + bbox[2]) / 2;
          if (centerLon < boundaryLon) {
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': bbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/tile_a.zip'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('server error', 500);
        }
        return http.Response.bytes(_zipOf('tile.asc', tileAGrid), 200);
      });

      // Must not throw despite the second tile's 500: tile A's data is
      // still returned instead of the whole fetch failing.
      final grid = await source.fetch(boundaryPoint, spanMeters: 200);

      expect(itemCalls, 2);
      expect(grid.rows, 2);
      expect(grid.cols, 2);
      expect(grid.depthAt(0, 0), closeTo(405.92 - 400.0, 1e-6));

      // The failed tile was never cached as a definitive answer, so a
      // later retry (e.g. once the network recovers) queries it again
      // rather than being permanently stuck as "no data".
      final again = await source.fetch(boundaryPoint, spanMeters: 200);
      expect(itemCalls, 3);
      expect(again.depthAt(0, 0), closeTo(405.92 - 400.0, 1e-6));
    });

    test('throws when every tile in the span fails transiently, so the '
        'resolver falls through instead of caching a false negative', () async {
      const boundaryPoint = GeoPoint(47.354865314, 8.563694834);
      var itemCalls = 0;
      final source = buildSource((req) async {
        itemCalls++;
        return http.Response('server error', 500);
      });

      await expectLater(
        source.fetch(boundaryPoint, spanMeters: 200),
        throwsA(isA<BathymetryFetchException>()),
      );
      expect(itemCalls, 2);
    });

    test('a missing tile inside the span is a gap, not a crash, when at least '
        'one neighboring tile has data', () async {
      // Same boundary point/span as above, but the east tile has no STAC
      // item at all (empty feature list) — a genuine coverage gap. Routed
      // by the request's own bbox rather than call order, since
      // bounded-concurrency fetches no longer guarantee which tile's
      // request lands first.
      const boundaryPoint = GeoPoint(47.354865314, 8.563694834);
      final boundaryLon = Lv95Transform.toWgs84(2685000, 1245500).longitude;
      const tileAGrid = '''
ncols 2
nrows 2
xllcorner 2684000
yllcorner 1245000
cellsize 500
nodata_value -9999
400.0 400.0
400.0 400.0
''';

      var itemCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          final bbox = _requestedBbox(req);
          final centerLon = (bbox[0] + bbox[2]) / 2;
          if (centerLon < boundaryLon) {
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': bbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/tile_a.zip'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'features': []}), 200);
        }
        return http.Response.bytes(_zipOf('tile.asc', tileAGrid), 200);
      });

      final grid = await source.fetch(boundaryPoint, spanMeters: 200);

      expect(itemCalls, 2);
      expect(grid.rows, 2);
      expect(grid.cols, 2);
      expect(grid.depthAt(0, 0), closeTo(405.92 - 400.0, 1e-6));
    });

    test('caps concurrent tile requests at maxConcurrentTileRequests for a '
        'span wide enough to need more tiles than the limit', () async {
      // 3x3 = 9 tiles for spanMeters 2500 (matches the realistic-tile-
      // count stitching test above), comfortably more than
      // SwissBathy3dSource.maxConcurrentTileRequests so a bounded worker
      // pool can be told apart from firing every tile's request at once.
      var active = 0;
      var peak = 0;
      // Once true, later requests (the tiles picked up after the first
      // release) resolve immediately instead of queuing a new gate --
      // otherwise those late gates would never be completed and the fetch
      // would hang forever, since the release loop below only runs once.
      var released = false;
      final pendingGates = <Completer<void>>[];

      final source = buildSource((req) async {
        if (released) {
          return http.Response(jsonEncode({'features': []}), 200);
        }
        active += 1;
        if (active > peak) peak = active;
        final gate = Completer<void>();
        pendingGates.add(gate);
        await gate.future;
        active -= 1;
        // Every tile reports "no data here" once released, so the fetch
        // fails cleanly once all nine are accounted for -- this test only
        // cares about how many requests were in flight at once, not the
        // resulting grid.
        return http.Response(jsonEncode({'features': []}), 200);
      });

      final pending = source.fetch(zurichseePoint, spanMeters: 2500);

      // Yield repeatedly so the worker pool spins up to its limit before
      // any gate is released.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(peak, SwissBathy3dSource.maxConcurrentTileRequests);

      released = true;
      for (final c in pendingGates) {
        c.complete();
      }
      await expectLater(pending, throwsA(isA<BathymetryFetchException>()));
    });

    test('a tile already cached from an earlier fetch is served without a '
        'repeat network call when a later, wider fetch spans it alongside a '
        'genuinely new neighboring tile', () async {
      // Same boundary point/span/tiles as the stitching test above.
      const boundaryPoint = GeoPoint(47.354865314, 8.563694834);
      final boundaryLon = Lv95Transform.toWgs84(2685000, 1245500).longitude;
      const tileAGrid = '''
ncols 2
nrows 2
xllcorner 2684000
yllcorner 1245000
cellsize 500
nodata_value -9999
400.0 400.0
400.0 400.0
''';
      const tileBGrid = '''
ncols 2
nrows 2
xllcorner 2685000
yllcorner 1245000
cellsize 500
nodata_value -9999
410.0 410.0
410.0 410.0
''';

      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          final bbox = _requestedBbox(req);
          final centerLon = (bbox[0] + bbox[2]) / 2;
          final href = centerLon < boundaryLon
              ? 'https://example.org/tile_a.zip'
              : 'https://example.org/tile_b.zip';
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': bbox,
                  'assets': {
                    'grid': {'href': href},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        final body = req.url.path.endsWith('tile_a.zip')
            ? tileAGrid
            : tileBGrid;
        return http.Response.bytes(_zipOf('tile.asc', body), 200);
      });

      // Narrow fetch centered well inside tile A only (not at the
      // boundary), caching just that one tile -- mirrors an earlier visit
      // to a dive site before this wider one.
      final tileACenter = Lv95Transform.toWgs84(2684500, 1245500);
      await source.fetch(
        GeoPoint(tileACenter.latitude, tileACenter.longitude),
        spanMeters: 100,
      );
      expect(itemCalls, 1);
      expect(downloadCalls, 1);

      // Wider fetch spans both tile A (already cached) and tile B (new).
      // The concurrency limit applies to the pool of tasks, but a
      // cache-hit task resolves without ever reaching the network, so
      // only tile B should trigger a fresh STAC lookup and download.
      final grid = await source.fetch(boundaryPoint, spanMeters: 200);
      expect(itemCalls, 2);
      expect(downloadCalls, 2);
      expect(grid.cols, 4);
    });
  });

  group('SwissBathy3dSource periodic freshness check', () {
    Future<void> backdateCheckedAt(GeoPoint point, DateTime checkedAt) async {
      final lv95 = Lv95Transform.fromWgs84(point.latitude, point.longitude);
      final tileKey = SwissBathy3dSource.tileKeyFor(lv95);
      await (db.update(
        db.swissBathyTileCache,
      )..where((t) => t.tileKey.equals(tileKey))).write(
        SwissBathyTileCacheCompanion(
          checkedAt: Value(checkedAt.millisecondsSinceEpoch),
        ),
      );
    }

    test('a stale cached tile triggers exactly one light metadata check and '
        'no download when the source version is unchanged', () async {
      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': _requestedBbox(req),
                  'properties': {'datetime': '2023-01-01T00:00:00Z'},
                  'assets': {
                    'grid': {'href': 'https://example.org/tile_grid.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      final first = await source.fetch(zurichseePoint, spanMeters: 100);
      expect(itemCalls, 1);
      expect(downloadCalls, 1);

      await backdateCheckedAt(
        zurichseePoint,
        DateTime.now().subtract(const Duration(days: 31)),
      );

      final second = await source.fetch(zurichseePoint, spanMeters: 100);
      expect(itemCalls, 2); // exactly one extra light metadata lookup
      expect(downloadCalls, 1); // unchanged version: no re-download
      expect(second.depthAt(0, 0), first.depthAt(0, 0));
    });

    test('a stale check matches back to the previously-covering candidate by '
        'href, not list position, so a still-present decoy does not trigger '
        'a spurious re-download (Copilot review)', () async {
      // The first fetch sees two candidates for the tile: a decoy whose
      // declared bbox overlaps but whose real content does not (Bug 14),
      // and the real one that actually covers it. _firstOverlappingCandidate
      // resolves to the real one, so ITS href/datetime -- not the decoy's,
      // and not just "whichever is candidates.first" -- is what a later
      // stale check must compare against.
      const decoyGrid = '''
ncols 4
nrows 4
xllcorner 2900000
yllcorner 1400000
cellsize 100
nodata_value -9999
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
1.0 1.0 1.0 1.0
''';

      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          final requestedBbox = _requestedBbox(req);
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': requestedBbox,
                  'properties': {'datetime': '2020-01-01T00:00:00Z'},
                  'assets': {
                    'grid': {'href': 'https://example.org/decoy.zip'},
                  },
                },
                {
                  'bbox': requestedBbox,
                  'properties': {'datetime': '2023-01-01T00:00:00Z'},
                  'assets': {
                    'grid': {'href': 'https://example.org/real.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        if (req.url.path.endsWith('decoy.zip')) {
          return http.Response.bytes(_zipOf('tile.asc', decoyGrid), 200);
        }
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      final first = await source.fetch(zurichseePoint, spanMeters: 100);
      expect(itemCalls, 1);
      // Both candidates are tried once during the initial resolution: the
      // decoy is downloaded and rejected before the real one is found.
      expect(downloadCalls, 2);

      await backdateCheckedAt(
        zurichseePoint,
        DateTime.now().subtract(const Duration(days: 31)),
      );

      // The stale check must recognize that the real candidate's own
      // datetime (2023-01-01) is unchanged. Comparing against
      // candidates.first (the decoy, 2020-01-01) instead -- the pre-fix
      // behavior -- would always look "changed" and force an unnecessary
      // re-download of both candidates on every single check.
      final second = await source.fetch(zurichseePoint, spanMeters: 100);
      expect(itemCalls, 2); // exactly one extra light metadata lookup
      expect(downloadCalls, 2); // unchanged version: no re-download
      expect(second.depthAt(0, 0), first.depthAt(0, 0));
    });

    test(
      'a stale cached tile is re-downloaded when the source version changed',
      () async {
        // xllcorner/yllcorner match zurichseePoint's own tile (2685_1240,
        // see gridBody's fixture header) so the re-downloaded grid still
        // overlaps the requested tile's LV95 bounding box and is not
        // discarded as a genuine "no overlap" gap by extractRawEsriSubgrid.
        const updatedGrid = '''
ncols 2
nrows 2
xllcorner 2685000
yllcorner 1240000
cellsize 500
nodata_value -9999
500.0 500.0
500.0 500.0
''';

        var itemCalls = 0;
        var downloadCalls = 0;
        final source = buildSource((req) async {
          if (req.url.path.endsWith('/items')) {
            itemCalls++;
            final datetime = itemCalls == 1
                ? '2023-01-01T00:00:00Z'
                : '2024-06-01T00:00:00Z';
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': _requestedBbox(req),
                    'properties': {'datetime': datetime},
                    'assets': {
                      'grid': {'href': 'https://example.org/tile_grid.zip'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          downloadCalls++;
          final body = downloadCalls == 1 ? gridBody : updatedGrid;
          return http.Response.bytes(_zipOf('tile.asc', body), 200);
        });

        final first = await source.fetch(zurichseePoint, spanMeters: 100);
        expect(downloadCalls, 1);

        await backdateCheckedAt(
          zurichseePoint,
          DateTime.now().subtract(const Duration(days: 31)),
        );

        final second = await source.fetch(zurichseePoint, spanMeters: 100);
        expect(itemCalls, 2);
        expect(downloadCalls, 2); // changed version: re-downloaded
        expect(second.depthAt(0, 0), isNot(first.depthAt(0, 0)));

        // The refreshed version is now cached: a third fetch right after
        // does not check again (checkedAt was just bumped).
        final third = await source.fetch(zurichseePoint, spanMeters: 100);
        expect(itemCalls, 2);
        expect(third.depthAt(0, 0), second.depthAt(0, 0));
      },
    );

    test(
      'a failed metadata check on a stale tile serves the cached grid '
      'without throwing, offline-safe like the fetch-failure fallback',
      () async {
        var itemCalls = 0;
        var downloadCalls = 0;
        final source = buildSource((req) async {
          if (req.url.path.endsWith('/items')) {
            itemCalls++;
            if (itemCalls == 1) {
              return http.Response(
                jsonEncode({
                  'features': [
                    {
                      'bbox': _requestedBbox(req),
                      'properties': {'datetime': '2023-01-01T00:00:00Z'},
                      'assets': {
                        'grid': {'href': 'https://example.org/tile_grid.zip'},
                      },
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response('server error', 500);
          }
          downloadCalls++;
          return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
        });

        final first = await source.fetch(zurichseePoint, spanMeters: 100);

        await backdateCheckedAt(
          zurichseePoint,
          DateTime.now().subtract(const Duration(days: 31)),
        );

        final second = await source.fetch(zurichseePoint, spanMeters: 100);
        expect(itemCalls, 2);
        expect(downloadCalls, 1); // the failed check never re-downloads
        expect(second.depthAt(0, 0), first.depthAt(0, 0));
      },
    );

    test('a tile cached before the freshness fields existed (checkedAt null) '
        'is treated as due for a check immediately', () async {
      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': _requestedBbox(req),
                  'properties': {'datetime': '2023-01-01T00:00:00Z'},
                  'assets': {
                    'grid': {'href': 'https://example.org/tile_grid.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      await source.fetch(zurichseePoint, spanMeters: 100);
      expect(itemCalls, 1);
      expect(downloadCalls, 1);

      // Simulate a row written before checkedAt/sourceDatetime existed.
      final lv95 = Lv95Transform.fromWgs84(
        zurichseePoint.latitude,
        zurichseePoint.longitude,
      );
      final tileKey = SwissBathy3dSource.tileKeyFor(lv95);
      await (db.update(
        db.swissBathyTileCache,
      )..where((t) => t.tileKey.equals(tileKey))).write(
        const SwissBathyTileCacheCompanion(
          checkedAt: Value(null),
          sourceDatetime: Value(null),
        ),
      );

      final grid = await source.fetch(zurichseePoint, spanMeters: 100);
      expect(itemCalls, 2); // checked immediately since checkedAt is null
      // A null sourceDatetime (pre-v15 row) never equals a real version
      // token, so this one-off check re-downloads once to establish a
      // baseline -- after which sourceDatetime is populated and later
      // checks behave like the "unchanged version" case above.
      expect(downloadCalls, 2);
      expect(grid.rows, 4);
    });
  });

  group('SwissBathy3dSource.refreshAllCachedTiles (manual reload)', () {
    test('no cached tiles: nothing to check, no HTTP calls', () async {
      final source = buildSource((_) async => http.Response('', 404));
      final summary = await source.refreshAllCachedTiles();
      expect(summary.total, 0);
      expect(summary.updated, 0);
      expect(summary.upToDate, 0);
      expect(summary.failed, 0);
    });

    test('revalidates a freshly cached tile immediately, without waiting for '
        'staleCheckInterval, and finds it unchanged', () async {
      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': _requestedBbox(req),
                  'properties': {'datetime': '2023-01-01T00:00:00Z'},
                  'assets': {
                    'grid': {'href': 'https://example.org/tile_grid.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      await source.fetch(zurichseePoint, spanMeters: 100);
      expect(itemCalls, 1);
      expect(downloadCalls, 1);

      // No backdating of checkedAt here: the manual action must revalidate
      // right away instead of waiting for staleCheckInterval to elapse.
      final summary = await source.refreshAllCachedTiles();
      expect(itemCalls, 2); // exactly one extra light metadata lookup
      expect(downloadCalls, 1); // unchanged version: no re-download
      expect(summary.total, 1);
      expect(summary.upToDate, 1);
      expect(summary.updated, 0);
      expect(summary.failed, 0);
    });

    test('re-downloads a cached tile whose version actually changed', () async {
      // xllcorner/yllcorner match zurichseePoint's own tile (2685_1240, see
      // gridBody's fixture header) so the re-downloaded grid still overlaps
      // the requested tile's LV95 bounding box instead of being discarded
      // as a genuine "no overlap" gap by extractRawEsriSubgrid.
      const updatedGrid = '''
ncols 2
nrows 2
xllcorner 2685000
yllcorner 1240000
cellsize 500
nodata_value -9999
500.0 500.0
500.0 500.0
''';
      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          final datetime = itemCalls == 1
              ? '2023-01-01T00:00:00Z'
              : '2024-06-01T00:00:00Z';
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': _requestedBbox(req),
                  'properties': {'datetime': datetime},
                  'assets': {
                    'grid': {'href': 'https://example.org/tile_grid.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        downloadCalls++;
        final body = downloadCalls == 1 ? gridBody : updatedGrid;
        return http.Response.bytes(_zipOf('tile.asc', body), 200);
      });

      final first = await source.fetch(zurichseePoint, spanMeters: 100);

      final summary = await source.refreshAllCachedTiles();
      expect(itemCalls, 2);
      expect(downloadCalls, 2); // changed version: re-downloaded
      expect(summary.updated, 1);
      expect(summary.upToDate, 0);
      expect(summary.failed, 0);

      final again = await source.fetch(zurichseePoint, spanMeters: 100);
      expect(again.depthAt(0, 0), isNot(first.depthAt(0, 0)));
    });

    test('a failed metadata check counts as failed and keeps the cached grid '
        'unchanged, offline-safe like the periodic check', () async {
      var itemCalls = 0;
      var downloadCalls = 0;
      final source = buildSource((req) async {
        if (req.url.path.endsWith('/items')) {
          itemCalls++;
          if (itemCalls == 1) {
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': _requestedBbox(req),
                    'properties': {'datetime': '2023-01-01T00:00:00Z'},
                    'assets': {
                      'grid': {'href': 'https://example.org/tile_grid.zip'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('server error', 500);
        }
        downloadCalls++;
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      final first = await source.fetch(zurichseePoint, spanMeters: 100);

      final summary = await source.refreshAllCachedTiles();
      expect(summary.failed, 1);
      expect(summary.updated, 0);
      expect(summary.upToDate, 0);
      expect(downloadCalls, 1); // no re-download attempted

      final again = await source.fetch(zurichseePoint, spanMeters: 100);
      expect(again.depthAt(0, 0), first.depthAt(0, 0));
    });

    test(
      'sweeps every cached tile independently and tallies mixed outcomes',
      () async {
        // Distinct lake, well outside zurichseePoint's tile (and away from
        // its own tile's boundary, so spanMeters: 100 stays single-tile).
        const bodenseePoint = GeoPoint(47.55, 9.20);

        // Each point needs its own tile-positioned grid body -- since
        // extractRawEsriSubgrid now requires the downloaded content to
        // actually overlap the requested tile's LV95 bounding box, reusing
        // gridBody (positioned only near Zürichsee) for bodenseePoint would
        // extract to a gap instead of data.
        String tileGridFor(GeoPoint point) {
          final lv95 = Lv95Transform.fromWgs84(point.latitude, point.longitude);
          final tileE = (lv95.easting / 1000).floor() * 1000;
          final tileN = (lv95.northing / 1000).floor() * 1000;
          return '''
ncols 2
nrows 2
xllcorner $tileE
yllcorner $tileN
cellsize 500
nodata_value -9999
400.0 400.0
400.0 400.0
''';
        }

        final zurichGrid = tileGridFor(zurichseePoint);
        final bodenseeGrid = tileGridFor(bodenseePoint);

        var itemCalls = 0;
        var downloadCalls = 0;
        final source = buildSource((req) async {
          if (req.url.path.endsWith('/items')) {
            itemCalls++;
            // Calls 1-2 are the initial fetches for the two tiles; call 3
            // (whichever tile the sweep checks first) finds no change,
            // call 4 (the other tile) fails transiently.
            if (itemCalls <= 3) {
              final bbox = _requestedBbox(req);
              final centerLon = (bbox[0] + bbox[2]) / 2;
              final href = centerLon < 9.0
                  ? 'https://example.org/zurich_tile.zip'
                  : 'https://example.org/bodensee_tile.zip';
              return http.Response(
                jsonEncode({
                  'features': [
                    {
                      'bbox': bbox,
                      'properties': {'datetime': '2023-01-01T00:00:00Z'},
                      'assets': {
                        'grid': {'href': href},
                      },
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response('server error', 500);
          }
          downloadCalls++;
          final body = req.url.path.endsWith('zurich_tile.zip')
              ? zurichGrid
              : bodenseeGrid;
          return http.Response.bytes(_zipOf('tile.asc', body), 200);
        });

        await source.fetch(zurichseePoint, spanMeters: 100);
        await source.fetch(bodenseePoint, spanMeters: 100);
        expect(itemCalls, 2);
        expect(downloadCalls, 2);

        final summary = await source.refreshAllCachedTiles();
        expect(summary.total, 2);
        expect(summary.upToDate, 1);
        expect(summary.failed, 1);
        expect(summary.updated, 0);
      },
    );

    test(
      'caps concurrent freshness checks at maxConcurrentTileRequests when '
      'more tiles are cached than the limit, the same bounded pool fetch '
      'uses -- the manual "reload map data" action and the periodic check '
      'must not each grow their own, independent concurrency policy',
      () async {
        // Five different lakes, so each fetch below caches exactly one
        // distinct tile -- comfortably more than
        // SwissBathy3dSource.maxConcurrentTileRequests.
        const points = [
          GeoPoint(47.25, 8.65), // Zürichsee
          GeoPoint(47.65, 9.30), // Bodensee
          GeoPoint(47.00, 8.45), // Vierwaldstättersee
          GeoPoint(46.70, 7.75), // Thunersee
          GeoPoint(47.14, 9.20), // Walensee
        ];

        // Each point needs its own tile-positioned grid body -- since
        // extractRawEsriSubgrid now requires the downloaded content to
        // actually overlap the requested tile's LV95 bounding box, a
        // single shared body (positioned near just one of these five
        // lakes) would extract to a gap for the other four.
        String tileGridFor(GeoPoint point) {
          final lv95 = Lv95Transform.fromWgs84(point.latitude, point.longitude);
          final tileE = (lv95.easting / 1000).floor() * 1000;
          final tileN = (lv95.northing / 1000).floor() * 1000;
          return '''
ncols 2
nrows 2
xllcorner $tileE
yllcorner $tileN
cellsize 500
nodata_value -9999
400.0 400.0
400.0 400.0
''';
        }

        final gridsByFilename = {
          for (var i = 0; i < points.length; i++)
            'tile_$i.zip': tileGridFor(points[i]),
        };

        // Nearest-point match so the mock can tell which of the five
        // widely-separated lakes a request's bbox belongs to, without
        // depending on the exact epsilon-buffered bbox math.
        int nearestPointIndex(List<double> bbox) {
          final centerLat = (bbox[1] + bbox[3]) / 2;
          final centerLon = (bbox[0] + bbox[2]) / 2;
          var bestIndex = 0;
          var bestDist = double.infinity;
          for (var i = 0; i < points.length; i++) {
            final d =
                (points[i].latitude - centerLat).abs() +
                (points[i].longitude - centerLon).abs();
            if (d < bestDist) {
              bestDist = d;
              bestIndex = i;
            }
          }
          return bestIndex;
        }

        var itemCalls = 0;
        var gatingEnabled = false;
        // Once true, later requests (the tile picked up after the first
        // release, since 5 tiles exceed the 4-worker pool) resolve
        // immediately instead of queuing a new gate -- otherwise that late
        // gate would never be completed and the sweep would hang forever,
        // since the release loop below only runs once.
        var released = false;
        var active = 0;
        var peak = 0;
        final pendingGates = <Completer<void>>[];

        final source = buildSource((req) async {
          if (req.url.path.endsWith('/items')) {
            itemCalls++;
            if (gatingEnabled && !released) {
              active += 1;
              if (active > peak) peak = active;
              final gate = Completer<void>();
              pendingGates.add(gate);
              await gate.future;
              active -= 1;
            }
            final bbox = _requestedBbox(req);
            final index = nearestPointIndex(bbox);
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': bbox,
                    'properties': {'datetime': '2023-01-01T00:00:00Z'},
                    'assets': {
                      'grid': {'href': 'https://example.org/tile_$index.zip'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          final filename = req.url.pathSegments.last;
          return http.Response.bytes(
            _zipOf('tile.asc', gridsByFilename[filename]!),
            200,
          );
        });

        // Sequential, un-gated setup: cache one tile per lake.
        for (final point in points) {
          await source.fetch(point, spanMeters: 100);
        }
        expect(itemCalls, 5);

        // Now the sweep itself, gated so peak concurrency is observable.
        gatingEnabled = true;
        final pending = source.refreshAllCachedTiles();
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(peak, SwissBathy3dSource.maxConcurrentTileRequests);

        released = true;
        for (final gate in pendingGates) {
          gate.complete();
        }
        final summary = await pending;
        expect(summary.total, 5);
        expect(summary.upToDate, 5);
      },
    );

    test('a cached "no tile here" negative is not part of the sweep, since '
        'there is no grid to revalidate', () async {
      var itemCalls = 0;
      final source = buildSource((req) async {
        itemCalls++;
        return http.Response(jsonEncode({'features': []}), 200);
      });

      await expectLater(
        source.fetch(zurichseePoint, spanMeters: 100),
        throwsA(isA<BathymetryFetchException>()),
      );
      expect(itemCalls, 1);

      final summary = await source.refreshAllCachedTiles();
      expect(summary.total, 0);
      expect(itemCalls, 1); // no extra lookup for the cached negative
    });
  });

  group('SwissBathy3dSource in the resolver chain', () {
    // Regression test for a bug observed after the swissBATHY3D integration:
    // a land coordinate outside every known lake stopped loading a 3D model
    // at all. Root cause turned out to be the multi-tile stitching bug (a
    // separate fix) rather than the fallback logic itself, but nothing
    // previously exercised the full resolver + real source combination for
    // this case — this locks that path in.
    test('a land coordinate outside every known lake falls through to the '
        'next resolver tier and still yields a result', () async {
      var httpCalls = 0;
      final swissSource = buildSource((_) async {
        httpCalls++;
        return http.Response('', 404);
      });
      final fallback = _FakeFallbackSource();

      final resolution = await BathymetryResolver(
        sources: [swissSource, fallback],
      ).resolve(alpsPoint);

      // covers() already excludes it; the tier makes no network call.
      expect(httpCalls, 0);
      expect(fallback.fetchCount, 1);
      expect(resolution.grid?.sourceId, 'fallback');
      expect(resolution.definitive, isTrue);
    });
  });
}

class _FakeFallbackSource implements BathymetrySource {
  int fetchCount = 0;

  @override
  String get id => 'fallback';

  @override
  bool get global => true;

  @override
  bool covers(GeoPoint center) => true;

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    fetchCount++;
    return BathymetryGrid(
      originLat: center.latitude,
      originLon: center.longitude,
      cellSizeLatDeg: 0.004,
      cellSizeLonDeg: 0.004,
      rows: 1,
      cols: 10,
      depthsMeters: [for (var i = 0; i < 10; i++) 50.0],
      sourceId: 'fallback',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );
  }
}
