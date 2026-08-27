import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/etopo_erddap_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  const bonaire = GeoPoint(12.16, -68.29);
  final body = File(
    'test/fixtures/bathymetry/etopo_bonaire.json',
  ).readAsStringSync();

  test('fetches and parses from the primary host', () async {
    final requested = <String>[];
    final source = EtopoErddapSource(
      client: MockClient((req) async {
        requested.add(req.url.toString());
        return http.Response(body, 200);
      }),
    );
    final grid = await source.fetch(bonaire, spanMeters: 4000);
    expect(grid.sourceId, 'etopo2022');
    expect(grid.rows, 3);
    expect(requested.single, contains('coastwatch.pfeg.noaa.gov'));
    expect(requested.single, contains('ETOPO_2022_v1_15s.json'));
  });

  test('fails over to the mirror when the primary errors', () async {
    final requested = <String>[];
    final source = EtopoErddapSource(
      client: MockClient((req) async {
        requested.add(req.url.host);
        if (req.url.host.contains('coastwatch')) {
          return http.Response('down', 500);
        }
        return http.Response(body, 200);
      }),
    );
    final grid = await source.fetch(bonaire, spanMeters: 4000);
    expect(grid.rows, 3);
    expect(requested, [
      'coastwatch.pfeg.noaa.gov',
      'oceanwatch.pifsc.noaa.gov',
    ]);
  });

  test('throws BathymetryFetchException when all hosts fail', () async {
    final source = EtopoErddapSource(
      client: MockClient((req) async => http.Response('down', 503)),
    );
    expect(
      () => source.fetch(bonaire, spanMeters: 4000),
      throwsA(isA<BathymetryFetchException>()),
    );
  });

  test('throws BathymetryFetchException on unparseable body', () async {
    final source = EtopoErddapSource(
      client: MockClient(
        (req) async => http.Response('<html>oops</html>', 200),
      ),
    );
    expect(
      () => source.fetch(bonaire, spanMeters: 4000),
      throwsA(isA<BathymetryFetchException>()),
    );
  });

  test('covers everywhere and is global', () {
    final source = EtopoErddapSource(
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(source.covers(const GeoPoint(-80, 170)), isTrue);
    expect(source.global, isTrue);
  });
}
