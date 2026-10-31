import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/repositories/reef_cache_dao.dart';
import 'package:submersion/features/reef/data/repositories/reef_repository.dart';
import 'package:submersion/features/reef/data/services/nearby_species_service.dart';
import 'package:submersion/features/reef/data/services/reef_habitat_service.dart';
import 'package:submersion/features/reef/data/services/reef_health_service.dart';
import 'package:submersion/features/reef/data/services/reef_protection_service.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/services/reef_coordinate_key.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

SpeciesCatalogMatcher _matcher() => SpeciesCatalogMatcher.fromJsonString(
  jsonEncode({
    'speciesKeys': {'2384460': 'sp_sixbar_wrasse'},
    'taxonKeys': [587],
  }),
);

String _facetBody(List<int> keys) => jsonEncode({
  'facets': [
    {
      'field': 'SPECIES_KEY',
      'counts': [
        for (final key in keys) {'name': '$key', 'count': 5},
      ],
    },
  ],
});

void main() {
  late LocalCacheDatabase db;
  late DateTime clock;
  late int habitatCalls;

  setUp(() {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    clock = DateTime.utc(2026, 7, 25, 12);
    habitatCalls = 0;
  });

  tearDown(() async => db.close());

  ReefRepository buildRepository({
    http.Client? habitatClient,
    http.Client? healthClient,
    http.Client? protectionClient,
    http.Client? speciesClient,
  }) {
    final ok = MockClient(
      (_) async => http.Response(jsonEncode({'features': []}), 200),
    );
    return ReefRepository(
      cache: ReefCacheDao(db, now: () => clock),
      habitat: ReefHabitatService(client: habitatClient ?? ok),
      health: ReefHealthService(
        client:
            healthClient ?? MockClient((_) async => http.Response('down', 503)),
      ),
      protection: ReefProtectionService(client: protectionClient ?? ok),
      species: NearbySpeciesService(
        client:
            speciesClient ??
            MockClient(
              (_) async => http.Response(jsonEncode({'facets': []}), 200),
            ),
        matcher: _matcher(),
      ),
    );
  }

  test('a successful health fetch round-trips through the cache', () async {
    var healthCalls = 0;
    final healthBody = jsonEncode({
      'table': {
        'columnNames': [
          'time',
          'latitude',
          'longitude',
          'CRW_SST',
          'CRW_SSTANOMALY',
          'CRW_HOTSPOT',
          'CRW_DHW',
          'CRW_DHW_mask',
        ],
        'rows': [
          ['2026-07-23T12:00:00Z', 12.175, -68.275, 30.56, 1.15, 0.96, 3.68, 0],
        ],
      },
    });
    final counting = MockClient((_) async {
      healthCalls++;
      return http.Response(healthBody, 200);
    });

    final repo = buildRepository(healthClient: counting);
    final first = await repo.currentHealthFor(const GeoPoint(12.16, -68.28));
    final second = await repo.currentHealthFor(const GeoPoint(12.16, -68.28));

    expect(healthCalls, 1);
    expect(first.status, ReefDataStatus.ok);
    expect(first.value!.sst, 30.56);
    // The cached copy decodes to the same value the network produced.
    expect(second, first);
  });

  test('a dated reading and current conditions cache apart', () async {
    var healthCalls = 0;
    final counting = MockClient((_) async {
      healthCalls++;
      return http.Response('down', 503);
    });

    final repo = buildRepository(healthClient: counting);
    await repo.healthFor(
      const GeoPoint(12.16, -68.28),
      DateTime.utc(2023, 9, 1),
    );
    await repo.currentHealthFor(const GeoPoint(12.16, -68.28));

    // Different variants (dated vs current), so both fetch.
    expect(healthCalls, 2);
  });

  test('habitatFor serves the second call from cache', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {'threat_txt': 'High'},
            },
          ],
        }),
        200,
      );
    });

    final repo = buildRepository(habitatClient: counting);
    final first = await repo.habitatFor(const GeoPoint(12.16, -68.28));
    final second = await repo.habitatFor(const GeoPoint(12.16, -68.28));

    expect(habitatCalls, 1);
    expect(first.value!.onReef, isTrue);
    expect(second.value!.threatLevel, 'High');
  });

  test('one provider failing does not blank the others', () async {
    final repo = buildRepository();
    const point = GeoPoint(12.16, -68.28);

    expect(
      (await repo.currentHealthFor(point)).status,
      ReefDataStatus.unavailable,
    );
    expect((await repo.habitatFor(point)).status, ReefDataStatus.empty);
    expect((await repo.protectionFor(point)).status, ReefDataStatus.empty);
  });

  test('a stalled species request does not hold the other parts', () async {
    final pending = Completer<http.Response>();
    final repo = buildRepository(
      speciesClient: MockClient((_) => pending.future),
    );
    const point = GeoPoint(12.16, -68.28);

    final species = repo.speciesFor(point);

    expect((await repo.habitatFor(point)).status, ReefDataStatus.empty);
    expect((await repo.protectionFor(point)).status, ReefDataStatus.empty);

    pending.complete(http.Response(jsonEncode({'facets': []}), 200));
    expect((await species).status, ReefDataStatus.empty);
  });

  test('protection and species round-trip through the cache', () async {
    var protectionCalls = 0;
    var speciesCalls = 0;
    final repo = buildRepository(
      protectionClient: MockClient((_) async {
        protectionCalls++;
        return http.Response(
          jsonEncode({
            'features': [
              {
                'attributes': {'site_name': 'Bonaire National Marine Park'},
              },
            ],
          }),
          200,
        );
      }),
      speciesClient: MockClient((_) async {
        speciesCalls++;
        return http.Response(_facetBody([2384460]), 200);
      }),
    );
    const point = GeoPoint(12.16, -68.28);

    final firstProtection = await repo.protectionFor(point);
    final secondProtection = await repo.protectionFor(point);
    final firstSpecies = await repo.speciesFor(point);
    final secondSpecies = await repo.speciesFor(point);

    expect(protectionCalls, 1);
    expect(speciesCalls, 1);
    expect(secondProtection, firstProtection);
    expect(secondSpecies, firstSpecies);
    expect(secondSpecies.value!.matched.single.speciesId, 'sp_sixbar_wrasse');
  });

  test('a partial species result is shown but never cached', () async {
    var searches = 0;
    final repo = buildRepository(
      speciesClient: MockClient((request) async {
        if (request.url.path.endsWith('/occurrence/search')) {
          searches++;
          return http.Response(_facetBody([2384460, 111]), 200);
        }
        return http.Response('down', 503);
      }),
    );
    const point = GeoPoint(12.16, -68.28);

    final first = await repo.speciesFor(point);
    final second = await repo.speciesFor(point);

    expect(first.status, ReefDataStatus.ok);
    expect(first.value!.namesIncomplete, isTrue);
    expect(second.value!.namesIncomplete, isTrue);
    expect(searches, 2, reason: 'the 30-day cache must not keep the gap');
  });

  test('a concurrent caller shares a partial species result', () async {
    var searches = 0;
    final repo = buildRepository(
      speciesClient: MockClient((request) async {
        if (request.url.path.endsWith('/occurrence/search')) {
          searches++;
          return http.Response(_facetBody([2384460, 111]), 200);
        }
        return http.Response('down', 503);
      }),
    );
    const point = GeoPoint(12.16, -68.28);

    final parts = await Future.wait([
      repo.speciesFor(point),
      repo.speciesFor(point),
    ]);

    expect(searches, 1);
    expect(parts[1].status, ReefDataStatus.ok);
    expect(parts[1].value!.matched, hasLength(1));
  });

  test('a concurrent caller shares an empty answer as empty', () async {
    final repo = buildRepository();
    const point = GeoPoint(12.16, -68.28);

    final parts = await Future.wait([
      repo.habitatFor(point),
      repo.habitatFor(point),
    ]);

    expect(parts[1].status, ReefDataStatus.empty);
  });

  test('a cached row that cannot be read is fetched again', () async {
    await ReefCacheDao(db, now: () => clock).write(
      provider: ReefProviderId.habitat,
      coordKey: ReefCoordinateKey.format(const GeoPoint(12.16, -68.28)),
      status: ReefDataStatus.ok,
      payloadJson: 'not json',
    );
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(jsonEncode({'features': []}), 200);
    });
    final repo = buildRepository(habitatClient: counting);

    final part = await repo.habitatFor(const GeoPoint(12.16, -68.28));

    expect(habitatCalls, 1);
    expect(part.status, ReefDataStatus.empty);
  });

  test('forgetFailure lets the next read reach the network', () async {
    var healthCalls = 0;
    var speciesCalls = 0;
    final repo = buildRepository(
      healthClient: MockClient((_) async {
        healthCalls++;
        return http.Response('down', 503);
      }),
      speciesClient: MockClient((_) async {
        speciesCalls++;
        return http.Response('down', 503);
      }),
    );
    const point = GeoPoint(12.16, -68.28);

    await repo.currentHealthFor(point);
    await repo.currentHealthFor(point);
    await repo.speciesFor(point);
    await repo.speciesFor(point);
    expect(healthCalls, 1);
    expect(speciesCalls, 1);

    await repo.forgetFailure(ReefProviderId.health, point);
    await repo.forgetFailure(ReefProviderId.species, point);
    await repo.currentHealthFor(point);
    await repo.speciesFor(point);

    expect(healthCalls, 2);
    expect(speciesCalls, 2);
  });

  test('forgetFailure leaves other parts cached', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(jsonEncode({'features': []}), 200);
    });
    final repo = buildRepository(habitatClient: counting);
    const point = GeoPoint(12.16, -68.28);

    await repo.habitatFor(point);
    await repo.currentHealthFor(point);

    await repo.forgetFailure(ReefProviderId.health, point);
    await repo.forgetFailure(ReefProviderId.habitat, point);
    await repo.habitatFor(point);

    expect(habitatCalls, 1, reason: 'an empty answer is a fact, not a failure');
  });

  test('a second call within the ttl serves from cache', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {'threat_txt': 'High'},
            },
          ],
        }),
        200,
      );
    });

    final repo = buildRepository(habitatClient: counting);
    await repo.habitatFor(const GeoPoint(12.16, -68.28));
    await repo.habitatFor(const GeoPoint(12.16, -68.28));

    expect(habitatCalls, 1);
  });

  test('coordinates within 110m share a cache entry', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(jsonEncode({'features': []}), 200);
    });

    final repo = buildRepository(habitatClient: counting);
    await repo.habitatFor(const GeoPoint(12.1601, -68.2801));
    await repo.habitatFor(const GeoPoint(12.1604, -68.2804));

    expect(habitatCalls, 1);
  });

  test('concurrent calls for the same key are deduplicated', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(jsonEncode({'features': []}), 200);
    });

    final repo = buildRepository(habitatClient: counting);
    await Future.wait([
      repo.habitatFor(const GeoPoint(12.16, -68.28)),
      repo.habitatFor(const GeoPoint(12.16, -68.28)),
      repo.habitatFor(const GeoPoint(12.16, -68.28)),
    ]);

    expect(habitatCalls, 1);
  });

  test('a failure is retried after the failure ttl', () async {
    final failing = MockClient((_) async {
      habitatCalls++;
      return http.Response('boom', 500);
    });

    final repo = buildRepository(habitatClient: failing);
    await repo.habitatFor(const GeoPoint(12.16, -68.28));
    clock = clock.add(const Duration(minutes: 30));
    await repo.habitatFor(const GeoPoint(12.16, -68.28));
    expect(habitatCalls, 1);

    clock = clock.add(const Duration(hours: 2));
    await repo.habitatFor(const GeoPoint(12.16, -68.28));
    expect(habitatCalls, 2);
  });

  test('healthFor caches a past dive date permanently', () async {
    var healthCalls = 0;
    final ok = MockClient(
      (_) async => http.Response(jsonEncode({'features': []}), 200),
    );
    final repo = ReefRepository(
      cache: ReefCacheDao(db, now: () => clock),
      habitat: ReefHabitatService(client: ok),
      health: ReefHealthService(
        client: MockClient((_) async {
          healthCalls++;
          return http.Response(
            jsonEncode({
              'table': {
                'columnNames': [
                  'time',
                  'latitude',
                  'longitude',
                  'CRW_SST',
                  'CRW_SSTANOMALY',
                  'CRW_HOTSPOT',
                  'CRW_DHW',
                  'CRW_DHW_mask',
                ],
                'rows': [
                  [
                    '2019-03-15T12:00:00Z',
                    -0.575,
                    130.675,
                    28.44,
                    0.0,
                    -0.51,
                    0.0,
                    0,
                  ],
                ],
              },
            }),
            200,
          );
        }),
      ),
      protection: ReefProtectionService(client: ok),
      species: NearbySpeciesService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'facets': []}), 200),
        ),
        matcher: _matcher(),
      ),
    );

    final date = DateTime.utc(2019, 3, 15);
    await repo.healthFor(const GeoPoint(-0.558, 130.690), date);
    clock = clock.add(const Duration(days: 3650));
    final second = await repo.healthFor(const GeoPoint(-0.558, 130.690), date);

    expect(healthCalls, 1);
    expect(second.status, ReefDataStatus.ok);
  });
}
