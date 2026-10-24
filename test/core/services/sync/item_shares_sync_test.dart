import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Sync of the profiles a trip or site is shared with (issue #2151): parent-
/// gated children of `trips` and `dive_sites`, like the hides.
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

  test('a trip share round-trips through fetch, delete and upsert', () async {
    await db
        .into(db.tripShares)
        .insert(
          TripSharesCompanion.insert(
            id: 'h1',
            tripId: 't1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    final fetched = await serializer.fetchRecord('tripShares', 'h1');
    expect(fetched, isNotNull);
    await serializer.deleteRecord('tripShares', 'h1');
    expect(await db.select(db.tripShares).get(), isEmpty);
    await serializer.upsertRecord('tripShares', fetched!);
    expect((await db.select(db.tripShares).get()).single.id, 'h1');
  });

  test('a site share round-trips through fetch, delete and upsert', () async {
    await db
        .into(db.siteShares)
        .insert(
          SiteSharesCompanion.insert(
            id: 'h2',
            siteId: 's1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    final fetched = await serializer.fetchRecord('siteShares', 'h2');
    expect(fetched, isNotNull);
    await serializer.deleteRecord('siteShares', 'h2');
    expect(await db.select(db.siteShares).get(), isEmpty);
    await serializer.upsertRecord('siteShares', fetched!);
    expect((await db.select(db.siteShares).get()).single.id, 'h2');
  });

  test('a peer copy of the same share under another id converges', () async {
    await db
        .into(db.tripShares)
        .insert(
          TripSharesCompanion.insert(
            id: 'zzz-local',
            tripId: 't1',
            diverId: 'b',
            createdAt: 1,
          ),
        );
    await serializer.upsertRecords('tripShares', [
      {
        'id': 'aaa-peer',
        'tripId': 't1',
        'diverId': 'b',
        'createdAt': 2,
        'hlc': null,
      },
    ]);
    final rows = await db.select(db.tripShares).get();
    expect(rows.map((r) => r.id), ['aaa-peer']);
  });

  test('both types are parent-gated children with their parents declared', () {
    expect(SyncDataSerializer.parentGatedChildEntities, contains('tripShares'));
    expect(SyncDataSerializer.parentGatedChildEntities, contains('siteShares'));
    expect(SyncService.entityHasUpdatedAt['tripShares'], isFalse);
    expect(SyncService.entityHasUpdatedAt['siteShares'], isFalse);
    expect(SyncService.parentRefs['tripShares']!.map((r) => r.parent).toSet(), {
      'trips',
      'divers',
    });
    expect(SyncService.parentRefs['siteShares']!.map((r) => r.parent).toSet(), {
      'diveSites',
      'divers',
    });
  });

  test('neither is a shared site library child entity', () {
    expect(
      SyncDataSerializer.librarySiteChildEntities,
      isNot(contains('siteShares')),
    );
  });
}
