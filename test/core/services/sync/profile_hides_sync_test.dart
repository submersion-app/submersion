import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Sync of a profile's hidden shared trips and sites (issue #2594): parent-
/// gated children of `trips` and `dive_sites`, like trip_equipment.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;
  const t = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Bonaire',
            startDate: t,
            endDate: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Salt Pier',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('a trip hide round-trips through fetch, delete and upsert', () async {
    await db
        .into(db.tripHides)
        .insert(
          TripHidesCompanion.insert(
            id: 'h1',
            tripId: 't1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    final fetched = await serializer.fetchRecord('tripHides', 'h1');
    expect(fetched, isNotNull);
    await serializer.deleteRecord('tripHides', 'h1');
    expect(await db.select(db.tripHides).get(), isEmpty);
    await serializer.upsertRecord('tripHides', fetched!);
    expect((await db.select(db.tripHides).get()).single.id, 'h1');
  });

  test('a site hide round-trips through fetch, delete and upsert', () async {
    await db
        .into(db.siteHides)
        .insert(
          SiteHidesCompanion.insert(
            id: 'h2',
            siteId: 's1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    final fetched = await serializer.fetchRecord('siteHides', 'h2');
    expect(fetched, isNotNull);
    await serializer.deleteRecord('siteHides', 'h2');
    expect(await db.select(db.siteHides).get(), isEmpty);
    await serializer.upsertRecord('siteHides', fetched!);
    expect((await db.select(db.siteHides).get()).single.id, 'h2');
  });

  test('a peer copy of the same hide under another id converges', () async {
    await db
        .into(db.tripHides)
        .insert(
          TripHidesCompanion.insert(
            id: 'zzz-local',
            tripId: 't1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    await serializer.upsertRecords('tripHides', [
      {
        'id': 'aaa-peer',
        'tripId': 't1',
        'diverId': 'b',
        'createdAt': 2,
        'hlc': null,
      },
    ]);
    final rows = await db.select(db.tripHides).get();
    expect(rows.map((r) => r.id), ['aaa-peer']);
  });

  test('both types are parent-gated children with their parents declared', () {
    expect(SyncDataSerializer.parentGatedChildEntities, contains('tripHides'));
    expect(SyncDataSerializer.parentGatedChildEntities, contains('siteHides'));
    expect(SyncService.entityHasUpdatedAt['tripHides'], isFalse);
    expect(SyncService.entityHasUpdatedAt['siteHides'], isFalse);
    expect(SyncService.parentRefs['tripHides']!.map((r) => r.parent).toSet(), {
      'trips',
      'divers',
    });
    expect(SyncService.parentRefs['siteHides']!.map((r) => r.parent).toSet(), {
      'diveSites',
      'divers',
    });
  });
}
