import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/esri_ascii_parser.dart';
import 'package:submersion/features/bathymetry/data/sources/gmrt_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  final body = File(
    'test/fixtures/bathymetry/gmrt_bonaire.asc',
  ).readAsStringSync();
  final when = DateTime.utc(2026, 7, 28);

  group('EsriAsciiGridParser', () {
    test('parses header, flips rows to south-first, negates elevation', () {
      final g = EsriAsciiGridParser.parse(
        body,
        sourceId: 'gmrt',
        fetchedAt: when,
      );
      expect(g.rows, 3);
      expect(g.cols, 4);
      // Origin is the CELL CENTER: corner + cellsize/2.
      expect(g.originLon, closeTo(-68.311 + 5.4931640625e-4 / 2, 1e-12));
      expect(g.originLat, closeTo(12.139 + 5.4931640625e-4 / 2, 1e-12));
      expect(g.cellSizeLatDeg, closeTo(5.4931640625e-4, 1e-15));
      // Last data line is the SOUTHERNMOST row -> grid row 0.
      expect(g.depthAt(0, 0), closeTo(355.00, 1e-9));
      // First data line is the northernmost -> grid row 2.
      expect(g.depthAt(2, 0), closeTo(348.48, 1e-9));
      // nodata sentinel becomes null.
      expect(g.depthAt(1, 2), isNull);
      // Land elevation +12.5 -> depth -12.5.
      expect(g.depthAt(0, 2), closeTo(-12.5, 1e-9));
      // Resolution derived from cellsize with the cos(latitude) factor:
      // 5.4931640625e-4 * 111320 * cos(12.14 deg) ~= 59.8 m.
      expect(g.resolutionMeters, closeTo(59.8, 1.0));
    });

    test('throws FormatException on a missing header field', () {
      expect(
        () => EsriAsciiGridParser.parse(
          'ncols 4\nnrows 3\n-1 -2 -3 -4',
          sourceId: 'gmrt',
          fetchedAt: when,
        ),
        throwsFormatException,
      );
    });
  });

  group('GmrtSource', () {
    test('requests esriascii at high resolution and parses the grid', () async {
      late Uri requested;
      final source = GmrtSource(
        client: MockClient((req) async {
          requested = req.url;
          return http.Response(body, 200);
        }),
      );
      final grid = await source.fetch(
        const GeoPoint(12.16, -68.29),
        spanMeters: 4000,
      );
      expect(grid.sourceId, 'gmrt');
      expect(requested.host, 'www.gmrt.org');
      expect(requested.queryParameters['format'], 'esriascii');
      expect(requested.queryParameters['resolution'], 'high');
      expect(
        double.parse(requested.queryParameters['north']!),
        greaterThan(double.parse(requested.queryParameters['south']!)),
      );
    });

    test(
      'throws BathymetryFetchException on server error or bad body',
      () async {
        final erroring = GmrtSource(
          client: MockClient((_) async => http.Response('oops', 500)),
        );
        expect(
          () => erroring.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000),
          throwsA(isA<BathymetryFetchException>()),
        );
        final garbled = GmrtSource(
          client: MockClient((_) async => http.Response('<html></html>', 200)),
        );
        expect(
          () => garbled.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000),
          throwsA(isA<BathymetryFetchException>()),
        );
      },
    );
  });
}
