import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/utils/lv95_transform.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_stac_client.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Regression test for Bug 11: two real, distinct Walensee dive sites
/// (Betlis / Schiffsstation Stralegg and Murg West) reportedly rendered a
/// PIXEL-IDENTICAL 3D depth profile, despite the swissBATHY3D debug panel
/// confirming each fetch used different tile ranges and different fetch
/// centers. Bug 10 (the 0.02 degree cache cell collision) is already fixed
/// and confirmed NOT the cause here.
///
/// This test drives the actual production path end to end -- mocked STAC
/// HTTP responses -> [SwissBathy3dSource.fetch] at the real production span
/// ([BathymetryResolver.defaultSpanMeters], 8 km, ~9x9 = up to 81 tiles) ->
/// [SiteSeascapeGeometryService.buildWithLabels] -> the rendered [Scene3d]
/// mesh -- rather than stopping at the geometry-utility unit level the way
/// Bug 5/6's tests did, since those did not surface the real symptom.
void main() {
  // Real coordinates from the bug report, both confirmed inside Walensee.
  const betlis = GeoPoint(47.1355029, 9.1445462);
  const murgWest = GeoPoint(47.1130533, 9.2086694);

  Uint8List zipOf(String entryName, String content) {
    final archive = Archive();
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  List<double> requestedBbox(http.Request req) =>
      req.url.queryParameters['bbox']!.split(',').map(double.parse).toList();

  // Small per-tile grids (real swissBATHY3D tiles are 500x500 at 2 m
  // resolution) keep this test fast even at the real 8 km / up-to-81-tile
  // production span: the point is exercising the real tiling, stitching and
  // rendering pipeline, not the real resolution.
  const cellsPerTile = 4;
  const cellSizeMeters = 250.0; // 4 * 250 = 1000 m: still a real 1 km tile.

  /// Deterministic, tile-identity-dependent elevation so grids built from
  /// different tile ranges are provably different, not coincidentally equal.
  String tileGrid(int tileE, int tileN) {
    final base = 380.0 + ((tileE * 7 + tileN * 13) % 40);
    final row = List.filled(cellsPerTile, base.toStringAsFixed(2)).join(' ');
    final buffer = StringBuffer()
      ..writeln('ncols $cellsPerTile')
      ..writeln('nrows $cellsPerTile')
      ..writeln('xllcorner ${tileE * 1000}')
      ..writeln('yllcorner ${tileN * 1000}')
      ..writeln('cellsize $cellSizeMeters')
      ..writeln('nodata_value -9999');
    for (var r = 0; r < cellsPerTile; r++) {
      buffer.writeln(row);
    }
    return buffer.toString();
  }

  /// One shared handler (and cache) for both sites, exactly like the real
  /// app reuses one [SwissBathyTileCacheRepository] across every site view:
  /// tiles common to both sites' spans (the bug report's ~28 of 81) come
  /// from cache on the second fetch, while each site's unique tiles are
  /// fetched fresh -- the actual overlap scenario the bug describes.
  Future<http.Response> handler(http.Request req) async {
    if (req.url.path.endsWith('/items')) {
      final bbox = requestedBbox(req);
      final centerLat = (bbox[1] + bbox[3]) / 2;
      final centerLon = (bbox[0] + bbox[2]) / 2;
      final lv95 = Lv95Transform.fromWgs84(centerLat, centerLon);
      final tE = (lv95.easting / 1000).floor();
      final tN = (lv95.northing / 1000).floor();
      return http.Response(
        jsonEncode({
          'features': [
            {
              'bbox': bbox,
              'assets': {
                'grid': {'href': 'https://example.org/${tE}_$tN.zip'},
              },
            },
          ],
        }),
        200,
      );
    }
    final match = RegExp(r'(-?\d+)_(-?\d+)\.zip$').firstMatch(req.url.path)!;
    final tileE = int.parse(match.group(1)!);
    final tileN = int.parse(match.group(2)!);
    return http.Response.bytes(zipOf('tile.asc', tileGrid(tileE, tileN)), 200);
  }

  test('two distinct real Walensee sites at the production span yield distinct '
      'stitched grids and distinct rendered terrain meshes', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final source = SwissBathy3dSource(
      tileCache: SwissBathyTileCacheRepository(db),
      stacClient: SwissStacClient(client: MockClient(handler)),
    );

    final gridBetlis = await source.fetch(
      betlis,
      spanMeters: BathymetryResolver.defaultSpanMeters,
    );
    final gridMurgWest = await source.fetch(
      murgWest,
      spanMeters: BathymetryResolver.defaultSpanMeters,
    );

    // The underlying stitched data must actually differ -- this mirrors
    // what the diagnostic panel already confirmed live (different tile
    // ranges, only ~28 of 81 tiles shared).
    expect(
      gridBetlis.originLat != gridMurgWest.originLat ||
          gridBetlis.originLon != gridMurgWest.originLon ||
          !listEquals(gridBetlis.depthsMeters, gridMurgWest.depthsMeters),
      isTrue,
      reason: 'the two sites\' stitched grids must not be identical',
    );

    final sceneBetlis = const SiteSeascapeGeometryService().buildWithLabels(
      SiteSeascapeInput(
        grid: gridBetlis,
        center: betlis,
        siteName: 'Betlis / Schiffsstation Stralegg',
        divePaths: const [],
        nearbySites: const [],
      ),
    );
    final sceneMurgWest = const SiteSeascapeGeometryService().buildWithLabels(
      SiteSeascapeInput(
        grid: gridMurgWest,
        center: murgWest,
        siteName: 'Murg West',
        divePaths: const [],
        nearbySites: const [],
      ),
    );

    // This is the actual, reported symptom: the rendered terrain mesh --
    // what the diver sees in the 3D view -- must differ between the two
    // sites, not just the raw grid data feeding it.
    final terrainBetlis = sceneBetlis.scene.layers.first.mesh;
    final terrainMurgWest = sceneMurgWest.scene.layers.first.mesh;
    expect(
      listEquals(terrainBetlis.positions, terrainMurgWest.positions) &&
          listEquals(terrainBetlis.colors, terrainMurgWest.colors),
      isFalse,
      reason:
          'Bug 11: the rendered terrain mesh must not be pixel-identical '
          'for two distinct real dive sites',
    );

    // And the scene bounds (what the "Entfernung"/distance axis reports)
    // must also reflect the two different fetch centers.
    final boxBetlis = BathymetryTerrainBuilder.enuBounds(gridBetlis, betlis);
    final boxMurgWest = BathymetryTerrainBuilder.enuBounds(
      gridMurgWest,
      murgWest,
    );
    expect(
      boxBetlis.minEast != boxMurgWest.minEast ||
          boxBetlis.maxEast != boxMurgWest.maxEast ||
          boxBetlis.minNorth != boxMurgWest.minNorth ||
          boxBetlis.maxNorth != boxMurgWest.maxNorth,
      isTrue,
    );
  });
}
