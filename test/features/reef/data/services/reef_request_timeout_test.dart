import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/services/nearby_species_service.dart';
import 'package:submersion/features/reef/data/services/reef_habitat_service.dart';
import 'package:submersion/features/reef/data/services/reef_health_service.dart';
import 'package:submersion/features/reef/data/services/reef_protection_service.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

const _point = GeoPoint(12.16, -68.28);
const _limit = Duration(milliseconds: 10);

/// A server that accepts the request and never answers.
http.Client _hanging() => MockClient((_) => Completer<http.Response>().future);

SpeciesCatalogMatcher _matcher() => SpeciesCatalogMatcher.fromJsonString(
  jsonEncode({
    'speciesKeys': {'2384460': 'sp_sixbar_wrasse'},
    'taxonKeys': [587],
  }),
);

String _facets(List<int> keys) => jsonEncode({
  'facets': [
    {
      'field': 'SPECIES_KEY',
      'counts': [
        for (final key in keys) {'name': '$key', 'count': 5},
      ],
    },
  ],
});

/// Answers the occurrence search, then applies [name] to each name lookup.
http.Client _speciesClient(
  List<int> keys,
  Future<http.Response> Function(http.Request) name,
) => MockClient((request) {
  if (request.url.path.endsWith('/occurrence/search')) {
    return Future.value(http.Response(_facets(keys), 200));
  }
  return name(request);
});

void main() {
  test('a habitat request that never answers settles unavailable', () async {
    final part = await ReefHabitatService(
      client: _hanging(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.unavailable);
  });

  test('a NOAA request that never answers settles unavailable', () async {
    final part = await ReefHealthService(
      client: _hanging(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.unavailable);
  });

  test('a protection request that never answers settles unavailable', () async {
    final part = await ReefProtectionService(
      client: _hanging(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.unavailable);
  });

  test('a GBIF search that never answers settles unavailable', () async {
    final part = await NearbySpeciesService(
      client: _hanging(),
      matcher: _matcher(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.unavailable);
  });

  test('a stalled name lookup keeps the records that did resolve', () async {
    final client = _speciesClient([2384460, 111, 222], (request) {
      if (request.url.path.endsWith('/111')) {
        return Completer<http.Response>().future;
      }
      return Future.value(
        http.Response(jsonEncode({'scientificName': 'Aplysina archeri'}), 200),
      );
    });

    final part = await NearbySpeciesService(
      client: client,
      matcher: _matcher(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.ok);
    expect(part.value!.matched, hasLength(1));
    expect(part.value!.unmatchedNames, ['Aplysina archeri']);
    expect(part.value!.namesIncomplete, isTrue);
  });

  test('a failed name lookup also marks the result incomplete', () async {
    final client = _speciesClient([2384460, 111], (_) {
      return Future.value(http.Response('slow down', 429));
    });

    final part = await NearbySpeciesService(
      client: client,
      matcher: _matcher(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.ok);
    expect(part.value!.namesIncomplete, isTrue);
  });

  test('a name lookup that will never succeed is a finished one', () async {
    final client = _speciesClient([2384460, 111], (_) {
      return Future.value(http.Response('no such taxon', 404));
    });

    final part = await NearbySpeciesService(
      client: client,
      matcher: _matcher(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.ok);
    expect(part.value!.namesIncomplete, isFalse);
  });

  test('losing every name is unavailable, not "nothing nearby"', () async {
    final client = _speciesClient([
      111,
      222,
    ], (_) => Completer<http.Response>().future);

    final part = await NearbySpeciesService(
      client: client,
      matcher: _matcher(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.status, ReefDataStatus.unavailable);
  });

  test('a terrestrial record is a finished lookup, not a failed one', () async {
    final client = _speciesClient([2384460, 111], (_) {
      return Future.value(
        http.Response(
          jsonEncode({'scientificName': 'Arum maculatum', 'family': 'Araceae'}),
          200,
        ),
      );
    });

    final part = await NearbySpeciesService(
      client: client,
      matcher: _matcher(),
      timeout: _limit,
    ).fetch(_point);

    expect(part.value!.unmatchedNames, isEmpty);
    expect(part.value!.namesIncomplete, isFalse);
  });

  test('namesIncomplete is not persisted', () {
    const incomplete = NearbySpecies(
      unmatchedNames: ['Aplysina archeri'],
      namesIncomplete: true,
    );

    final restored = NearbySpecies.fromJson(incomplete.toJson());

    expect(incomplete.toJson().containsKey('namesIncomplete'), isFalse);
    expect(restored.namesIncomplete, isFalse);
  });
}
