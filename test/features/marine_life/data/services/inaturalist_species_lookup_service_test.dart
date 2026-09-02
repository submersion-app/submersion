import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/services/inaturalist_species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

String _fixture(String name) =>
    File('test/fixtures/inaturalist/$name').readAsStringSync();

Matcher _kind(SpeciesLookupErrorKind kind) =>
    isA<SpeciesLookupException>().having((e) => e.kind, 'kind', kind);

void main() {
  test(
    'a regioned or uppercase locale is normalized for request and cache',
    () async {
      final sent = <String?>[];
      final client = MockClient((request) async {
        sent.add(request.url.queryParameters['locale']);
        return http.Response(_fixture('autocomplete_whale_shark_de.json'), 200);
      });
      final service = INaturalistSpeciesLookupService(client: client);

      // The cache key already lowercases the tag, so 'DE' and 'de' share one
      // entry. Sending the raw tag would have them share a single cached
      // answer while asking iNaturalist for two different localizations.
      await service.search('whale shark', locale: 'DE');
      await service.search('whale shark', locale: 'de');

      expect(sent, ['de']);
    },
  );

  test('resolve normalizes the locale the same way', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_fixture('taxon_52188_de.json'), 200);
    });
    final service = INaturalistSpeciesLookupService(client: client);

    await service.resolve(52188, locale: 'DE');

    expect(captured.url.queryParameters['locale'], 'de');
  });

  test(
    'search hits the autocomplete endpoint with query, locale and agent',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_fixture('autocomplete_whale_shark_de.json'), 200);
      });
      final service = INaturalistSpeciesLookupService(client: client);

      final hits = await service.search('whale shark', locale: 'de');

      expect(captured.url.host, 'api.inaturalist.org');
      expect(captured.url.path, '/v1/taxa/autocomplete');
      expect(captured.url.queryParameters['q'], 'whale shark');
      expect(captured.url.queryParameters['locale'], 'de');
      expect(captured.url.queryParameters['per_page'], '10');
      expect(captured.url.queryParameters['is_active'], 'true');
      expect(captured.headers['user-agent'], contains('Submersion'));
      expect(hits.first.commonName, 'Walhai');
    },
  );

  test('resolve fetches the taxon and maps category and class', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_fixture('taxon_52188_de.json'), 200);
    });
    final service = INaturalistSpeciesLookupService(client: client);

    final result = await service.resolve(52188, locale: 'de');

    expect(captured.url.path, '/v1/taxa/52188');
    expect(captured.url.queryParameters['locale'], 'de');
    expect(result.taxonId, 52188);
    expect(result.commonName, 'Walhai');
    expect(result.scientificName, 'Rhincodon typus');
    expect(result.category, SpeciesCategory.shark);
    expect(result.taxonomyClass, 'Chondrichthyes');
  });

  test(
    'resolve falls back to the scientific name without a common name',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"results":[{"id":9,"name":"Nomen nudum","rank":"species",'
          '"ancestors":[{"rank":"kingdom","name":"Animalia"}]}]}',
          200,
        ),
      );

      final result = await INaturalistSpeciesLookupService(
        client: client,
      ).resolve(9, locale: 'en');

      expect(result.commonName, 'Nomen nudum');
      expect(result.category, SpeciesCategory.invertebrate);
      expect(result.taxonomyClass, isNull);
    },
  );

  test('a non-200 answer is a server error', () async {
    final client = MockClient((_) async => http.Response('nope', 503));

    expect(
      () => INaturalistSpeciesLookupService(
        client: client,
      ).search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.server)),
    );
  });

  test('a body that is not JSON is malformed', () async {
    final client = MockClient((_) async => http.Response('<html>', 200));

    expect(
      () => INaturalistSpeciesLookupService(
        client: client,
      ).search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.malformed)),
    );
  });

  test('a socket failure is offline', () async {
    final client = MockClient((_) async => throw const SocketException('down'));

    expect(
      () => INaturalistSpeciesLookupService(
        client: client,
      ).search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.offline)),
    );
  });

  test('a slow answer is a timeout', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{"results":[]}', 200);
    });
    final service = INaturalistSpeciesLookupService(
      client: client,
      timeout: const Duration(milliseconds: 20),
    );

    expect(
      () => service.search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.timeout)),
    );
  });

  test('a repeated search is served from the session cache', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls += 1;
      return http.Response(_fixture('autocomplete_whale_shark_de.json'), 200);
    });
    final service = INaturalistSpeciesLookupService(client: client);

    await service.search('Whale shark', locale: 'de');
    await service.search('  whale shark ', locale: 'DE');
    await service.search('whale shark', locale: 'en');

    expect(calls, 2);
  });
}
