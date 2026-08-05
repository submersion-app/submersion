import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/emodnet_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  final body = File(
    'test/fixtures/bathymetry/emodnet_carib.json',
  ).readAsStringSync();

  EmodnetSource source(MockClientHandler handler) =>
      EmodnetSource(client: MockClient(handler));

  test('covers Europe and the Caribbean tile, nothing else', () {
    final s = source((_) async => http.Response('', 500));
    expect(s.covers(const GeoPoint(43.2, 4.5)), isTrue); // Mediterranean
    expect(s.covers(const GeoPoint(12.16, -68.29)), isTrue); // Bonaire
    expect(s.covers(const GeoPoint(36.6, -121.9)), isFalse); // Monterey
    expect(s.covers(const GeoPoint(-8.5, 115.5)), isFalse); // Bali
    expect(s.global, isFalse);
  });

  test('selects the Caribbean dataset for a Caribbean coordinate', () async {
    late Uri requested;
    final s = source((req) async {
      requested = req.url;
      return http.Response(body, 200);
    });
    final grid = await s.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000);
    expect(grid.sourceId, 'emodnet');
    expect(requested.path, contains('bathymetry_dtm_carib_2024'));
    expect(requested.query, contains('elevation'));
  });

  test('selects the European dataset for a European coordinate', () async {
    late Uri requested;
    final s = source((req) async {
      requested = req.url;
      return http.Response(body, 200);
    });
    await s.fetch(const GeoPoint(43.2, 4.5), spanMeters: 4000);
    expect(requested.path, contains('bathymetry_dtm_2024'));
    expect(requested.path, isNot(contains('carib')));
  });

  test('throws BathymetryFetchException on server error', () async {
    final s = source((_) async => http.Response('down', 502));
    expect(
      () => s.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000),
      throwsA(isA<BathymetryFetchException>()),
    );
  });
}
