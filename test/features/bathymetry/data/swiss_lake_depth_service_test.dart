import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/utils/lv95_transform.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_stac_client.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/features/bathymetry/data/swiss_lake_depth_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

Uint8List _zipOf(String entryName, String content) {
  final archive = Archive();
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  final gridBody = File(
    'test/fixtures/bathymetry/swissbathy3d_sample.asc',
  ).readAsStringSync();
  const zurichseePoint = GeoPoint(47.25, 8.65);
  const bonairePoint = GeoPoint(12.16, -68.29);
  // Inside the fixture grid's upper-right quadrant (cell-center corner is
  // LV95 2685050,1240050 with a 100 m cellsize — see swiss_lv95_grid_test),
  // chosen to avoid the nodata cell at grid row 1 / col 1 so all four
  // bilinear-interpolation neighbors are real values.
  final insideFixtureGrid = Lv95Transform.toWgs84(2685300, 1240300);
  final insideFixtureGridPoint = GeoPoint(
    insideFixtureGrid.latitude,
    insideFixtureGrid.longitude,
  );

  late LocalCacheDatabase db;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  SwissLakeDepthService buildService(
    Future<http.Response> Function(http.Request) handler,
  ) => SwissLakeDepthService(
    SwissBathy3dSource(
      tileCache: SwissBathyTileCacheRepository(db),
      stacClient: SwissStacClient(client: MockClient(handler)),
    ),
  );

  test(
    'returns null immediately for a coordinate outside Switzerland',
    () async {
      var calls = 0;
      final service = buildService((_) async {
        calls++;
        return http.Response('', 404);
      });
      expect(await service.depthForCoordinate(bonairePoint), isNull);
      expect(calls, 0);
    },
  );

  test(
    'returns a bilinearly interpolated depth for a covered coordinate',
    () async {
      final service = buildService((req) async {
        if (req.url.path.endsWith('/items')) {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': req.url.queryParameters['bbox']!
                      .split(',')
                      .map(double.parse)
                      .toList(),
                  'assets': {
                    'grid': {'href': 'https://example.org/tile_grid.zip'},
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response.bytes(_zipOf('tile.asc', gridBody), 200);
      });

      final depth = await service.depthForCoordinate(insideFixtureGridPoint);
      expect(depth, isNotNull);
      expect(depth, greaterThan(0));
    },
  );

  test('returns null when the STAC lookup fails', () async {
    final service = buildService((_) async => http.Response('oops', 500));
    expect(await service.depthForCoordinate(zurichseePoint), isNull);
  });
}
