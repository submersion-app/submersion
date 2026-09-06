import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/noaa_dem_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The shape the live `identify` endpoint returns: a stack of catalogue
/// items, each with its own cell size in DEGREES.
String identifyBody(List<({String name, double lowPs})> items) => jsonEncode({
  'objectId': 0,
  'value': '-3.87793',
  'catalogItems': {
    'features': [
      for (final i in items)
        {
          'attributes': {'Name': i.name, 'LowPS': i.lowPs, 'HighPS': i.lowPs},
        },
    ],
  },
});

/// A 2x2 single-tile float32 TIFF, every pixel 8 m below sea level.
Uint8List tinyTiff() {
  const width = 2, height = 2, tileSize = 4, entries = 10;
  const headerLen = 8;
  const ifdLen = 2 + entries * 12 + 4;
  const pixelStart = headerLen + ifdLen;
  final out = BytesBuilder();
  final head = ByteData(headerLen);
  head.setUint8(0, 0x49);
  head.setUint8(1, 0x49);
  head.setUint16(2, 42, Endian.little);
  head.setUint32(4, headerLen, Endian.little);
  out.add(head.buffer.asUint8List());
  final ifd = ByteData(ifdLen);
  ifd.setUint16(0, entries, Endian.little);
  var e = 2;
  void entry(int tag, int type, int count, int value) {
    ifd.setUint16(e, tag, Endian.little);
    ifd.setUint16(e + 2, type, Endian.little);
    ifd.setUint32(e + 4, count, Endian.little);
    if (type == 3 && count == 1) {
      ifd.setUint16(e + 8, value, Endian.little);
      ifd.setUint16(e + 10, 0, Endian.little);
    } else {
      ifd.setUint32(e + 8, value, Endian.little);
    }
    e += 12;
  }

  entry(256, 3, 1, width);
  entry(257, 3, 1, height);
  entry(258, 3, 1, 32);
  entry(259, 3, 1, 1);
  entry(277, 3, 1, 1);
  entry(322, 3, 1, tileSize);
  entry(323, 3, 1, tileSize);
  entry(324, 4, 1, pixelStart);
  entry(325, 4, 1, tileSize * tileSize * 4);
  entry(339, 3, 1, 3);
  ifd.setUint32(ifdLen - 4, 0, Endian.little);
  out.add(ifd.buffer.asUint8List());
  final px = ByteData(tileSize * tileSize * 4);
  for (var i = 0; i < tileSize * tileSize; i++) {
    px.setFloat32(i * 4, -8.0, Endian.little);
  }
  out.add(px.buffer.asUint8List());
  return out.toBytes();
}

void main() {
  const keys = GeoPoint(25.010, -80.376);
  const bonaire = GeoPoint(12.093, -68.287);

  group('probe', () {
    test('returns the finest catalogue item, converted to meters', () async {
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            identifyBody([
              (name: 'ETOPO_2022_v1_15s_surface_elev', lowPs: 0.0041666),
              (name: 'ncei19_n25x25_w080x50_2016v1', lowPs: 3.086419e-05),
            ]),
            200,
          ),
        ),
      );
      final cap = await source.probe(keys);
      expect(cap, isNotNull);
      // A geographic cell is square in DEGREES, so its two sides differ in
      // meters. The capability reports the COARSER side: at 25 N that is
      // the latitude axis, 3.086e-05 * 110540 = 3.41 m.
      expect(cap!.cellSizeMeters, closeTo(3.41, 0.05));
      expect(cap.detail, 'ncei19_n25x25_w080x50_2016v1');
    });

    test('asks for maxItemCount so the catalogue is not truncated', () async {
      // Load-bearing: the default truncates to three items, which hides a
      // covered site's DEM behind the ETOPO background.
      Uri? seen;
      final source = NoaaDemSource(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(identifyBody([]), 200);
        }),
      );
      await source.probe(keys);
      expect(seen!.queryParameters['maxItemCount'], '25');
      expect(seen!.queryParameters['returnCatalogItems'], 'true');
      expect(seen!.queryParameters['f'], 'json');
      expect(seen!.path, endsWith('/identify'));
    });

    test('declines when the best item is coarser than the threshold', () async {
      // Bonaire: the mosaic holds nothing but its ETOPO background there,
      // which the ETOPO tier already serves directly.
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            identifyBody([
              (name: 'ETOPO_2022_v1_15s_surface_elev', lowPs: 0.0041666),
            ]),
            200,
          ),
        ),
      );
      expect(await source.probe(bonaire), isNull);
    });

    test('accepts a mid-range regional DEM', () async {
      // La Jolla measured 10.3 m, comfortably inside the threshold.
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            identifyBody([(name: 'san_diego_navd88', lowPs: 1.1e-04)]),
            200,
          ),
        ),
      );
      final cap = await source.probe(const GeoPoint(32.85, -117.27));
      expect(cap!.cellSizeMeters, lessThan(NoaaDemSource.usefulCellSizeMeters));
      expect(cap.detail, 'san_diego_navd88');
    });

    test('declines on an empty catalogue', () async {
      final source = NoaaDemSource(
        client: MockClient((req) async => http.Response(identifyBody([]), 200)),
      );
      expect(await source.probe(keys), isNull);
    });

    test(
      'declines on an ArcGIS error envelope returned with HTTP 200',
      () async {
        final source = NoaaDemSource(
          client: MockClient(
            (req) async => http.Response(
              jsonEncode({
                'error': {'code': 400, 'message': 'Invalid geometry'},
              }),
              200,
            ),
          ),
        );
        expect(await source.probe(keys), isNull);
      },
    );

    test('declines on a catalogue item with no usable cell size', () async {
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'catalogItems': {
                'features': [
                  {
                    'attributes': {'Name': 'broken', 'LowPS': 0},
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );
      expect(await source.probe(keys), isNull);
    });

    test('declines on a non-200', () async {
      final source = NoaaDemSource(
        client: MockClient((req) async => http.Response('nope', 503)),
      );
      expect(await source.probe(keys), isNull);
    });

    test(
      'declines rather than throwing when the service is unreachable',
      () async {
        // A probe must never throw: one unreachable source cannot be allowed
        // to block the others.
        final source = NoaaDemSource(
          client: MockClient((req) async => throw const SocketishError()),
        );
        expect(await source.probe(keys), isNull);
      },
    );

    test(
      'reports the coarser axis, so latitude cannot flatter a DEM',
      () async {
        // A 3 arc-second cell is 92.1 m north-south everywhere. Converting on
        // the longitude axis alone shrinks it with cos(latitude): at 60 N it
        // reads 46.4 m and slips under the 50 m threshold, so a 92 m DEM
        // would be accepted as high resolution. NOAA's mosaic really does
        // hold 3 arc-second Coastal Relief Model tiles, and Alaskan coastal
        // water is exactly where they are the best available.
        final source = NoaaDemSource(
          client: MockClient(
            (req) async => http.Response(
              identifyBody([(name: 'crm_vol8', lowPs: 8.33e-04)]),
              200,
            ),
          ),
        );
        expect(await source.probe(const GeoPoint(60.0, -149.0)), isNull);
        // The same tile is already rejected at the equator today, which is
        // the inconsistency this removes.
        expect(await source.probe(const GeoPoint(0.0, -90.0)), isNull);
      },
    );

    test('a genuinely fine DEM is still accepted at high latitude', () async {
      // The guard must not reject real high-resolution Alaskan coverage:
      // a 1 arc-second cell is 30.7 m north-south, inside the threshold.
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            identifyBody([(name: 'alaska_1s', lowPs: 2.78e-04)]),
            200,
          ),
        ),
      );
      final cap = await source.probe(const GeoPoint(60.0, -149.0));
      expect(cap, isNotNull);
      expect(cap!.cellSizeMeters, closeTo(30.7, 0.2));
    });

    test(
      'uses the longitude axis near the equator, where it is the longer',
      () async {
        // A degree of longitude at the equator is 111320 m against latitude's
        // 110540, so the coarser axis is not always the latitude one.
        final source = NoaaDemSource(
          client: MockClient(
            (req) async => http.Response(
              identifyBody([(name: 'equatorial', lowPs: 1.0e-04)]),
              200,
            ),
          ),
        );
        final cap = await source.probe(const GeoPoint(0.0, -90.0));
        expect(cap!.cellSizeMeters, closeTo(11.132, 0.005));
      },
    );
  });

  group('fetch', () {
    test('requests a float32 tiff over the span and parses it', () async {
      Uri? seen;
      final source = NoaaDemSource(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response.bytes(tinyTiff(), 200);
        }),
      );
      final g = await source.fetch(keys, spanMeters: 2000);
      expect(seen!.path, endsWith('/exportImage'));
      expect(seen!.queryParameters['format'], 'tiff');
      expect(seen!.queryParameters['pixelType'], 'F32');
      expect(seen!.queryParameters['bboxSR'], '4326');
      expect(seen!.queryParameters['imageSR'], '4326');
      expect(
        seen!.queryParameters['size'],
        '${NoaaDemSource.requestDim},${NoaaDemSource.requestDim}',
      );
      expect(g.rows, 2);
      expect(g.cols, 2);
      expect(g.depthAt(0, 0), closeTo(8.0, 1e-6));
      expect(g.sourceId, NoaaDemSource.sourceId);
    });

    test(
      'claims a resolution derived from the span and request size',
      () async {
        final source = NoaaDemSource(
          client: MockClient((_) async => http.Response.bytes(tinyTiff(), 200)),
        );
        final g = await source.fetch(keys, spanMeters: 2000);
        expect(
          g.resolutionMeters,
          closeTo(2000 / NoaaDemSource.requestDim, 1e-9),
        );
      },
    );

    test('throws BathymetryFetchException on a non-200', () async {
      final source = NoaaDemSource(
        client: MockClient((req) async => http.Response('down', 500)),
      );
      expect(
        () => source.fetch(keys, spanMeters: 2000),
        throwsA(isA<BathymetryFetchException>()),
      );
    });

    test('throws BathymetryFetchException on an error envelope', () async {
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response('{"error":{"code":400}}', 200),
        ),
      );
      expect(
        () => source.fetch(keys, spanMeters: 2000),
        throwsA(isA<BathymetryFetchException>()),
      );
    });
  });

  test('is not global, so a dry answer never proves land', () {
    expect(NoaaDemSource().global, isFalse);
    expect(NoaaDemSource().id, NoaaDemSource.sourceId);
  });
}

/// Stands in for a transport-level failure without importing dart:io.
class SocketishError implements Exception {
  const SocketishError();
}
