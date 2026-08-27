import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/repositories/reef_cache_dao.dart';
import 'package:submersion/features/reef/data/repositories/reef_repository.dart';
import 'package:submersion/features/reef/data/services/nearby_species_service.dart';
import 'package:submersion/features/reef/data/services/reef_habitat_service.dart';
import 'package:submersion/features/reef/data/services/reef_health_service.dart';
import 'package:submersion/features/reef/data/services/reef_protection_service.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/services/species_catalog_matcher.dart';

SpeciesCatalogMatcher _matcher() => SpeciesCatalogMatcher.fromJsonString(
  jsonEncode({
    'speciesKeys': <String, String>{},
    'taxonKeys': [587],
  }),
);

void main() {
  late LocalCacheDatabase db;
  late DateTime clock;
  late int habitatCalls;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 7, 25, 12);
    habitatCalls = 0;
  });

  tearDown(() async => db.close());

  ReefRepository buildRepository({
    http.Client? habitatClient,
    http.Client? healthClient,
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
      protection: ReefProtectionService(client: ok),
      species: NearbySpeciesService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'facets': []}), 200),
        ),
        matcher: _matcher(),
      ),
    );
  }

  test(
    'includeHealth false issues no health request and caches nothing',
    () async {
      var healthCalls = 0;
      final counting = MockClient((_) async {
        healthCalls++;
        return http.Response('down', 503);
      });

      final repo = buildRepository(healthClient: counting);
      final snapshot = await repo.snapshotFor(
        const GeoPoint(41.0, -81.5),
        includeHealth: false,
      );

      expect(healthCalls, 0);
      expect(snapshot.health.status, ReefDataStatus.empty);
      // The other three parts fetched normally.
      expect(snapshot.habitat.status, ReefDataStatus.empty);
      expect(snapshot.protection.status, ReefDataStatus.empty);

      // Nothing was cached for health: a later includeHealth fetch really
      // goes to the network.
      await repo.snapshotFor(const GeoPoint(41.0, -81.5));
      expect(healthCalls, 1);
    },
  );

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
    final first = await repo.snapshotFor(const GeoPoint(12.16, -68.28));
    final second = await repo.snapshotFor(const GeoPoint(12.16, -68.28));

    expect(healthCalls, 1);
    expect(first.health.status, ReefDataStatus.ok);
    expect(first.health.value!.sst, 30.56);
    // The cached copy decodes to the same value the network produced.
    expect(second.health, first.health);
  });

  test('snapshotFor with a date keys the health cache by that date', () async {
    var healthCalls = 0;
    final counting = MockClient((_) async {
      healthCalls++;
      return http.Response('down', 503);
    });

    final repo = buildRepository(healthClient: counting);
    await repo.snapshotFor(
      const GeoPoint(12.16, -68.28),
      date: DateTime.utc(2023, 9, 1),
    );
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));

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

  test('habitatFor shares the cache entry with snapshotFor', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(jsonEncode({'features': []}), 200);
    });

    final repo = buildRepository(habitatClient: counting);
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));
    await repo.habitatFor(const GeoPoint(12.16, -68.28));

    expect(habitatCalls, 1);
  });

  test('one provider failing does not blank the others', () async {
    final repo = buildRepository();
    final snapshot = await repo.snapshotFor(const GeoPoint(12.16, -68.28));

    expect(snapshot.health.status, ReefDataStatus.unavailable);
    expect(snapshot.habitat.status, ReefDataStatus.empty);
    expect(snapshot.protection.status, ReefDataStatus.empty);
    expect(snapshot.allUnavailable, isFalse);
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
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));

    expect(habitatCalls, 1);
  });

  test('coordinates within 110m share a cache entry', () async {
    final counting = MockClient((_) async {
      habitatCalls++;
      return http.Response(jsonEncode({'features': []}), 200);
    });

    final repo = buildRepository(habitatClient: counting);
    await repo.snapshotFor(const GeoPoint(12.1601, -68.2801));
    await repo.snapshotFor(const GeoPoint(12.1604, -68.2804));

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
      repo.snapshotFor(const GeoPoint(12.16, -68.28)),
      repo.snapshotFor(const GeoPoint(12.16, -68.28)),
      repo.snapshotFor(const GeoPoint(12.16, -68.28)),
    ]);

    expect(habitatCalls, 1);
  });

  test('a failure is retried after the failure ttl', () async {
    final failing = MockClient((_) async {
      habitatCalls++;
      return http.Response('boom', 500);
    });

    final repo = buildRepository(habitatClient: failing);
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));
    clock = clock.add(const Duration(minutes: 30));
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));
    expect(habitatCalls, 1);

    clock = clock.add(const Duration(hours: 2));
    await repo.snapshotFor(const GeoPoint(12.16, -68.28));
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
