import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The profiles a trip or site is shared with (issue #2151). 'me' owns the
/// items; 'son' and 'daughter' are the other profiles.
void main() {
  late AppDatabase db;
  late ItemSharesRepository repository;
  const trip = SharedItemKind.trip;
  const site = SharedItemKind.site;

  Future<Set<String>> tripShareDivers(String tripId) async => {
    for (final r in await (db.select(
      db.tripShares,
    )..where((t) => t.tripId.equals(tripId))).get())
      r.diverId,
  };

  Future<bool> tripFlag(String tripId) async => (await (db.select(
    db.trips,
  )..where((t) => t.id.equals(tripId))).getSingle()).isShared;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = ItemSharesRepository();
    await seedDivers(db, ['me', 'son', 'daughter']);
    await seedTrip(db, 'bonaire', owner: 'me');
    await seedSite(db, 'pier', owner: 'me');
  });

  tearDown(tearDownTestDatabase);

  test('setSharing by a non-owner writes nothing and returns false', () async {
    final done = await repository.setSharing(
      trip,
      'bonaire',
      ItemSharing.all,
      actingDiverId: 'son',
    );
    expect(done, isFalse);
    expect(await tripFlag('bonaire'), isFalse);
    expect(await db.select(db.tripShares).get(), isEmpty);
  });

  test('setSharing on a missing item returns false', () async {
    expect(
      await repository.setSharing(
        trip,
        'nope',
        ItemSharing.all,
        actingDiverId: 'me',
      ),
      isFalse,
    );
  });

  test('setSharing transitions between nobody, people and Everyone', () async {
    await clearPendingMarks(db);
    await repository.setSharing(
      trip,
      'bonaire',
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    expect(await tripShareDivers('bonaire'), {'son'});
    expect(await tripFlag('bonaire'), isFalse);
    final sonRow = (await db.select(db.tripShares).get()).single;
    expect(
      await pendingCount(db, ItemSharesRepository.tripEntity, sonRow.id),
      1,
    );

    await repository.setSharing(
      trip,
      'bonaire',
      ItemSharing.all,
      actingDiverId: 'me',
    );
    expect(await tripShareDivers('bonaire'), isEmpty);
    expect(await tripFlag('bonaire'), isTrue);
    expect(await tombstoneCount(db, ItemSharesRepository.tripEntity), 1);
    expect(await pendingCount(db, 'trips', 'bonaire'), 1);

    await repository.setSharing(
      trip,
      'bonaire',
      const ItemSharing(profileIds: {'daughter'}),
      actingDiverId: 'me',
    );
    expect(await tripShareDivers('bonaire'), {'daughter'});
    expect(await tripFlag('bonaire'), isFalse);

    await repository.setSharing(
      trip,
      'bonaire',
      ItemSharing.none,
      actingDiverId: 'me',
    );
    expect(await tripShareDivers('bonaire'), isEmpty);
    expect(await tripFlag('bonaire'), isFalse);
  });

  test('setSharing keeps rows it does not change', () async {
    await repository.setSharing(
      trip,
      'bonaire',
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    final before = (await db.select(db.tripShares).get()).single.id;
    await repository.setSharing(
      trip,
      'bonaire',
      const ItemSharing(profileIds: {'son', 'daughter'}),
      actingDiverId: 'me',
    );
    final rows = await db.select(db.tripShares).get();
    expect(rows.map((r) => r.id), contains(before));
    expect(rows, hasLength(2));
  });

  test('setSharing keeps a profile hide when it is unticked', () async {
    await repository.setSharing(
      trip,
      'bonaire',
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    await db
        .into(db.tripHides)
        .insert(
          TripHidesCompanion.insert(
            id: 'h1',
            tripId: 'bonaire',
            diverId: 'son',
            createdAt: 1,
          ),
        );
    await repository.setSharing(
      trip,
      'bonaire',
      ItemSharing.none,
      actingDiverId: 'me',
    );
    expect(await db.select(db.tripHides).get(), hasLength(1));
  });

  test('setSharing drops the owner own id', () async {
    await repository.setSharing(
      site,
      'pier',
      const ItemSharing(profileIds: {'me', 'son'}),
      actingDiverId: 'me',
    );
    final rows = await db.select(db.siteShares).get();
    expect(rows.map((r) => r.diverId), ['son']);
  });

  test('sharingOf reads nobody, people and Everyone', () async {
    expect(await repository.sharingOf(trip, 'bonaire'), ItemSharing.none);
    await repository.setSharing(
      trip,
      'bonaire',
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    expect(
      await repository.sharingOf(trip, 'bonaire'),
      const ItemSharing(profileIds: {'son'}),
    );
  });

  test('sharingOf prefers Everyone over a stale share row', () async {
    await seedTrip(db, 'raced', owner: 'me', shared: true);
    await db
        .into(db.tripShares)
        .insert(
          TripSharesCompanion.insert(
            id: 'stale',
            tripId: 'raced',
            diverId: 'son',
            createdAt: 1,
          ),
        );
    expect(await repository.sharingOf(trip, 'raced'), ItemSharing.all);
    expect((await repository.sharingOfAll(trip, ['raced', 'bonaire'])), {
      'raced': ItemSharing.all,
      'bonaire': ItemSharing.none,
    });
    await repository.setSharing(
      trip,
      'raced',
      ItemSharing.all,
      actingDiverId: 'me',
    );
    expect(await tripShareDivers('raced'), isEmpty);
  });

  test('addSharing adds to owned items and skips others', () async {
    await seedTrip(db, 'everyone', owner: 'me', shared: true);
    await seedTrip(db, 'withDaughter', owner: 'me');
    await seedTrip(db, 'sons', owner: 'son', shared: true);
    await repository.setSharing(
      trip,
      'withDaughter',
      const ItemSharing(profileIds: {'daughter'}),
      actingDiverId: 'me',
    );
    final result = await repository.addSharing(
      trip,
      ['bonaire', 'everyone', 'withDaughter', 'sons'],
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    // Every owned item is shared with the son now, including the one
    // already shared with everyone, which needed no change.
    expect(result.itemsShared, 3);
    expect(result.skippedNotOwned, 1);
    expect(await tripShareDivers('bonaire'), {'son'});
    expect(await tripShareDivers('withDaughter'), {'daughter', 'son'});
    expect(await tripShareDivers('everyone'), isEmpty);
    expect(await tripFlag('everyone'), isTrue);
    expect(await tripShareDivers('sons'), isEmpty);
  });

  test('addSharing with Everyone makes each owned item Everyone', () async {
    final result = await repository.addSharing(
      trip,
      ['bonaire'],
      ItemSharing.all,
      actingDiverId: 'me',
    );
    expect(result.itemsShared, 1);
    expect(await tripFlag('bonaire'), isTrue);
  });

  test('addSharing with nobody changes nothing', () async {
    final result = await repository.addSharing(
      trip,
      ['bonaire'],
      ItemSharing.none,
      actingDiverId: 'me',
    );
    expect(result.itemsShared, 0);
    expect(await db.select(db.tripShares).get(), isEmpty);
  });

  test(
    'deleteShares then restoreShares round-trips ids and tombstones',
    () async {
      await repository.setSharing(
        site,
        'pier',
        const ItemSharing(profileIds: {'son', 'daughter'}),
        actingDiverId: 'me',
      );
      final ids = {for (final r in await db.select(db.siteShares).get()) r.id};
      final removed = await db.transaction(
        () => repository.deleteShares(site, ['pier']),
      );
      expect(removed.map((s) => s.id).toSet(), ids);
      expect(await db.select(db.siteShares).get(), isEmpty);
      expect(await tombstoneCount(db, ItemSharesRepository.siteEntity), 2);

      await repository.restoreShares(site, removed);
      expect({for (final r in await db.select(db.siteShares).get()) r.id}, ids);
      expect(await tombstoneCount(db, ItemSharesRepository.siteEntity), 0);
    },
  );

  test('deleteShares can remove one profile only', () async {
    await repository.setSharing(
      trip,
      'bonaire',
      const ItemSharing(profileIds: {'son', 'daughter'}),
      actingDiverId: 'me',
    );
    await db.transaction(
      () => repository.deleteShares(trip, ['bonaire'], diverId: 'son'),
    );
    expect(await tripShareDivers('bonaire'), {'daughter'});
  });

  test('the trip and site lists refresh on a share write', () async {
    final trips = expectLater(
      TripRepository().watchTripsChanges(),
      emitsThrough(anything),
    );
    final sites = expectLater(
      SiteRepository().watchSitesChanges(),
      emitsThrough(anything),
    );
    await db
        .into(db.tripShares)
        .insert(
          TripSharesCompanion.insert(
            id: 'x1',
            tripId: 'bonaire',
            diverId: 'son',
            createdAt: 1,
          ),
        );
    await db
        .into(db.siteShares)
        .insert(
          SiteSharesCompanion.insert(
            id: 'x2',
            siteId: 'pier',
            diverId: 'son',
            createdAt: 1,
          ),
        );
    await trips;
    await sites;
  });

  test(
    'itemIdsWithShares lists the items shared with someone by name',
    () async {
      await seedTrip(db, 'other', owner: 'me');
      await repository.setSharing(
        trip,
        'bonaire',
        const ItemSharing(profileIds: {'son', 'daughter'}),
        actingDiverId: 'me',
      );
      expect(await repository.itemIdsWithShares(trip), {'bonaire'});
      expect(await repository.itemIdsWithShares(site), isEmpty);
    },
  );

  test(
    'storedProfileIds reads the rows even beside the everyone flag',
    () async {
      await seedTrip(db, 'raced', owner: 'me', shared: true);
      await db
          .into(db.tripShares)
          .insert(
            TripSharesCompanion.insert(
              id: 'stale',
              tripId: 'raced',
              diverId: 'son',
              createdAt: 1,
            ),
          );
      expect(await repository.storedProfileIds(trip, 'raced'), {'son'});
      expect(await repository.storedProfileIds(trip, 'bonaire'), isEmpty);
    },
  );

  test('reads more items than one SQL variable list holds', () async {
    final ids = [for (var i = 0; i < 1200; i++) 't$i'];
    for (final id in ids) {
      await seedTrip(db, id, owner: 'me');
    }
    final result = await repository.addSharing(
      trip,
      ids,
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    expect(result.itemsShared, 1200);
    expect((await repository.sharingOfAll(trip, ids)).length, 1200);
  });

  test('isVisibleTo follows ownership, Everyone, share rows and library '
      'membership', () async {
    await seedSite(db, 'everyone', owner: 'me', shared: true);
    await seedSite(db, 'library');
    await db.customStatement(
      "UPDATE dive_sites SET shared_library_id = 'lib1' WHERE id = 'library'",
    );
    await db
        .into(db.sharedLibraryMemberships)
        .insert(
          SharedLibraryMembershipsCompanion.insert(
            id: 'm1',
            diverId: 'daughter',
            libraryId: 'lib1',
            memberId: 'member-1',
            displayName: 'Dana',
            libraryName: 'Club',
            backendKind: 's3',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await repository.setSharing(
      site,
      'pier',
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    expect(await repository.isVisibleTo(site, 'pier', 'me'), isTrue);
    expect(await repository.isVisibleTo(site, 'pier', 'son'), isTrue);
    expect(await repository.isVisibleTo(site, 'pier', 'daughter'), isFalse);
    expect(await repository.isVisibleTo(site, 'everyone', 'son'), isTrue);
    expect(await repository.isVisibleTo(site, 'library', 'daughter'), isTrue);
    expect(await repository.isVisibleTo(site, 'library', 'son'), isFalse);
    expect(await repository.isVisibleTo(trip, 'bonaire', 'son'), isFalse);
    expect(await repository.isVisibleTo(site, 'missing', 'me'), isFalse);
  });

  test('itemIdsWithShares leaves out a shared site library site', () async {
    await repository.setSharing(
      site,
      'pier',
      const ItemSharing(profileIds: {'son'}),
      actingDiverId: 'me',
    );
    await db.customStatement(
      "UPDATE dive_sites SET shared_library_id = 'lib1' WHERE id = 'pier'",
    );
    expect(await repository.itemIdsWithShares(site), isEmpty);
  });
}
