import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/nearby_species_service.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

SpeciesCatalogMatcher _matcher() => SpeciesCatalogMatcher.fromJsonString(
  jsonEncode({
    'speciesKeys': {'2384460': 'sp_sixbar_wrasse', '5231676': 'sp_star_coral'},
    'orderKeys': [587, 1362],
  }),
);

String _facetBody(List<List<Object>> counts) => jsonEncode({
  'count': 1000,
  'facets': [
    {
      'field': 'SPECIES_KEY',
      'counts': counts.map((c) => {'name': c[0], 'count': c[1]}).toList(),
    },
  ],
});

void main() {
  group('NearbySpeciesService.fetch', () {
    test('sends licence, quality and order filters', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(_facetBody([]), 200);
      });

      await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(12.160, -68.280));

      // GBIF takes latitude first, unlike ArcGIS.
      expect(captured.queryParameters['geoDistance'], '12.160,-68.280,5km');
      expect(
        captured.queryParametersAll['license'],
        containsAll(<String>['CC0_1_0', 'CC_BY_4_0']),
      );
      expect(captured.queryParameters['occurrenceStatus'], 'PRESENT');
      expect(captured.queryParameters['hasGeospatialIssue'], 'false');
      expect(
        captured.queryParametersAll['taxonKey'],
        containsAll(<String>['587', '1362']),
      );
      expect(captured.queryParameters['facet'], 'speciesKey');
      expect(captured.queryParameters['limit'], '0');
    });

    test('sets a User-Agent, which GBIF asks integrators to do', () async {
      late Map<String, String> headers;
      final client = MockClient((request) async {
        headers = request.headers;
        return http.Response(_facetBody([]), 200);
      });

      await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(1, 2));

      expect(headers['user-agent'], contains('Submersion'));
    });

    test('splits results into catalog matches and unmatched names', () async {
      final client = MockClient((request) async {
        if (request.url.path.startsWith('/v1/species/')) {
          return http.Response(
            jsonEncode({'scientificName': 'Aplysina archeri'}),
            200,
          );
        }
        return http.Response(
          _facetBody([
            ['5231676', 300],
            ['9999999', 278],
            ['2384460', 120],
          ]),
          200,
        );
      });

      final result = await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(12.160, -68.280));

      expect(result.status, ReefDataStatus.ok);
      expect(result.value!.matched.map((m) => m.speciesId), [
        'sp_star_coral',
        'sp_sixbar_wrasse',
      ]);
      expect(result.value!.matched.first.occurrenceCount, 300);
      expect(result.value!.unmatchedNames, ['Aplysina archeri']);
    });

    test('caps the unmatched tail at 25 entries', () async {
      final counts = List.generate(
        60,
        (i) => <Object>['${900000 + i}', 60 - i],
      );
      var nameLookups = 0;
      final client = MockClient((request) async {
        if (request.url.path.startsWith('/v1/species/')) {
          nameLookups++;
          return http.Response(
            jsonEncode({'scientificName': 'Species $nameLookups'}),
            200,
          );
        }
        return http.Response(_facetBody(counts), 200);
      });

      final result = await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(1, 2));

      expect(result.value!.unmatchedNames, hasLength(25));
      expect(nameLookups, 25);
    });

    // Sequentially these would be 25 round trips before the tier can render.
    test('resolves unmatched names concurrently', () async {
      var inFlight = 0;
      var peakInFlight = 0;
      final counts = List.generate(
        10,
        (i) => <Object>['${900000 + i}', 10 - i],
      );
      final client = MockClient((request) async {
        if (request.url.path.startsWith('/v1/species/')) {
          inFlight++;
          peakInFlight = inFlight > peakInFlight ? inFlight : peakInFlight;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          inFlight--;
          return http.Response(
            jsonEncode({
              'scientificName': 'Species ${request.url.pathSegments.last}',
            }),
            200,
          );
        }
        return http.Response(_facetBody(counts), 200);
      });

      final result = await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(1, 2));

      expect(result.value!.unmatchedNames, hasLength(10));
      expect(peakInFlight, greaterThan(1), reason: 'lookups ran sequentially');
    });

    test('drops unmatched entries whose name lookup fails', () async {
      final client = MockClient((request) async {
        if (request.url.path.startsWith('/v1/species/')) {
          return http.Response('nope', 500);
        }
        return http.Response(
          _facetBody([
            ['9999999', 10],
          ]),
          200,
        );
      });

      final result = await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(1, 2));

      expect(result.status, ReefDataStatus.empty);
    });

    test('returns empty when no species are recorded nearby', () async {
      final client = MockClient(
        (_) async => http.Response(_facetBody([]), 200),
      );
      final result = await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.empty);
    });

    test('returns unavailable on HTTP 429 rate limiting', () async {
      final client = MockClient((_) async => http.Response('slow down', 429));
      final result = await NearbySpeciesService(
        client: client,
        matcher: _matcher(),
      ).fetch(const GeoPoint(1, 2));
      expect(result.status, ReefDataStatus.unavailable);
    });
  });
}
