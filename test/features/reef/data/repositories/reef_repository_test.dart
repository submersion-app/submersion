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
    'orderKeys': [587],
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

  ReefRepository buildRepository({http.Client? habitatClient}) {
    final ok = MockClient(
      (_) async => http.Response(jsonEncode({'features': []}), 200),
    );
    return ReefRepository(
      cache: ReefCacheDao(db, now: () => clock),
      habitat: ReefHabitatService(client: habitatClient ?? ok),
      health: ReefHealthService(
        client: MockClient((_) async => http.Response('down', 503)),
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
