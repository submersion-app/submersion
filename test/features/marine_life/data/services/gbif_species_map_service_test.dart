import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/marine_life/data/services/gbif_species_map_service.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

SpeciesCatalogMatcher _matcher() => SpeciesCatalogMatcher.fromJsonString(
  '{"speciesKeys": {"2417522": "sp_whale_shark"}, "taxonKeys": [1]}',
);

http.Response _match(Map<String, Object?> body) =>
    http.Response(jsonEncode(body), 200);

void main() {
  group('resolveTaxonKey', () {
    test('prefers the bundled key and makes no request', () async {
      final client = MockClient((_) async {
        fail('no request expected for a bundled key');
      });
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      final key = await service.resolveTaxonKey(
        speciesId: 'sp_whale_shark',
        scientificName: 'Rhincodon typus',
      );

      expect(key, 2417522);
    });

    test('matches by scientific name', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return _match({
          'usageKey': 9241141,
          'rank': 'SPECIES',
          'matchType': 'EXACT',
          'status': 'ACCEPTED',
        });
      });
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      final key = await service.resolveTaxonKey(
        speciesId: 'custom-1',
        scientificName: 'Mobula alfredi',
      );

      expect(key, 9241141);
      expect(sent.url.host, 'api.gbif.org');
      expect(sent.url.path, '/v1/species/match');
      expect(sent.url.queryParameters['name'], 'Mobula alfredi');
      expect(sent.url.queryParameters['strict'], 'true');
      expect(sent.url.queryParameters['rank'], 'SPECIES');
      expect(
        sent.headers['User-Agent'],
        'Submersion/1.0 (https://submersion.app)',
      );
    });

    test('follows a synonym to its accepted key', () async {
      final client = MockClient(
        (_) async => _match({
          'usageKey': 5,
          'acceptedUsageKey': 7,
          'rank': 'SPECIES',
          'matchType': 'EXACT',
          'status': 'SYNONYM',
        }),
      );
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      final key = await service.resolveTaxonKey(
        speciesId: 'custom-1',
        scientificName: 'Manta alfredi',
      );

      expect(key, 7);
    });

    test('returns null for a non-species match', () async {
      final client = MockClient(
        (_) async => _match({
          'usageKey': 3,
          'rank': 'GENUS',
          'matchType': 'EXACT',
          'status': 'ACCEPTED',
        }),
      );
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      expect(
        await service.resolveTaxonKey(
          speciesId: 'custom-1',
          scientificName: 'Mobula',
        ),
        isNull,
      );
    });

    test('returns null for a fuzzy match', () async {
      final client = MockClient(
        (_) async => _match({
          'usageKey': 3,
          'rank': 'SPECIES',
          'matchType': 'FUZZY',
          'status': 'ACCEPTED',
        }),
      );
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      expect(
        await service.resolveTaxonKey(
          speciesId: 'custom-1',
          scientificName: 'Mobula alfredii',
        ),
        isNull,
      );
    });

    test('returns null with no scientific name and makes no request', () async {
      final client = MockClient((_) async {
        fail('no request expected without a scientific name');
      });
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      expect(await service.resolveTaxonKey(speciesId: 'custom-1'), isNull);
      expect(
        await service.resolveTaxonKey(
          speciesId: 'custom-2',
          scientificName: '   ',
        ),
        isNull,
      );
    });

    test('throws on HTTP 500 and does not cache the failure', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('oops', 500);
      });
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      for (var i = 0; i < 2; i++) {
        await expectLater(
          service.resolveTaxonKey(
            speciesId: 'custom-1',
            scientificName: 'Mobula alfredi',
          ),
          throwsA(isA<GbifUnavailableException>()),
        );
      }
      expect(calls, 2);
    });

    test('throws on a timeout', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.resolveTaxonKey(
          speciesId: 'custom-1',
          scientificName: 'Mobula alfredi',
        ),
        throwsA(isA<GbifUnavailableException>()),
      );
    });

    test('throws when the network call itself fails', () async {
      final client = MockClient((_) async => throw http.ClientException('x'));
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      await expectLater(
        service.resolveTaxonKey(
          speciesId: 'custom-1',
          scientificName: 'Mobula alfredi',
        ),
        throwsA(isA<GbifUnavailableException>()),
      );
    });

    test('a corrected scientific name asks again', () async {
      final names = <String?>[];
      final client = MockClient((request) async {
        names.add(request.url.queryParameters['name']);
        return request.url.queryParameters['name'] == 'Mobula alfredi'
            ? _match({
                'usageKey': 9241141,
                'rank': 'SPECIES',
                'matchType': 'EXACT',
                'status': 'ACCEPTED',
              })
            : _match({'matchType': 'NONE'});
      });
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      expect(
        await service.resolveTaxonKey(
          speciesId: 'custom-1',
          scientificName: 'Mobula alfredy',
        ),
        isNull,
      );
      expect(
        await service.resolveTaxonKey(
          speciesId: 'custom-1',
          scientificName: 'Mobula alfredi',
        ),
        9241141,
      );
      expect(names, ['Mobula alfredy', 'Mobula alfredi']);
    });

    test('caches an answer per species id', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _match({
          'usageKey': 9241141,
          'rank': 'SPECIES',
          'matchType': 'EXACT',
          'status': 'ACCEPTED',
        });
      });
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      for (var i = 0; i < 2; i++) {
        await service.resolveTaxonKey(
          speciesId: 'custom-1',
          scientificName: 'Mobula alfredi',
        );
      }
      expect(calls, 1);
    });

    test('caches a confident no-match too', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _match({'matchType': 'NONE'});
      });
      final service = GbifSpeciesMapService(
        client: client,
        matcher: _matcher(),
      );

      for (var i = 0; i < 2; i++) {
        expect(
          await service.resolveTaxonKey(
            speciesId: 'custom-1',
            scientificName: 'Nonexistus fakeus',
          ),
          isNull,
        );
      }
      expect(calls, 1);
    });
  });

  group('tileUrlTemplate', () {
    test('uses the adhoc endpoint with both licences', () {
      final url = GbifSpeciesMapService.tileUrlTemplate(9241141);

      expect(
        url,
        startsWith(
          'https://api.gbif.org/v2/map/occurrence/adhoc/{z}/{x}/{y}@1x.png?',
        ),
      );
      expect(url, contains('taxonKey=9241141'));
      expect(url, contains('license=CC0_1_0'));
      expect(url, contains('license=CC_BY_4_0'));
      expect(url, contains('occurrenceStatus=PRESENT'));
      expect(url, contains('hasGeospatialIssue=false'));
    });
  });

  test('close closes the HTTP client', () {
    final client = _ClosingClient();
    GbifSpeciesMapService(client: client, matcher: _matcher()).close();

    expect(client.closed, isTrue);
  });
}

class _ClosingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => closed = true;
}
