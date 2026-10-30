import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Deleting a profile hands a trip or site it shared with chosen profiles to
/// one of them, rather than deleting it (issue #2151). 'parent' is deleted;
/// 'daughter' is the default profile, so Everyone items go to her.
void main() {
  late AppDatabase db;
  late ItemSharesRepository shares;

  Future<void> shareWith(
    SharedItemKind kind,
    String id,
    String diverId,
    int createdAt,
  ) async {
    final row = (
      id: 'share-$id-$diverId',
      itemId: id,
      diverId: diverId,
      createdAt: createdAt,
    );
    await shares.restoreShares(kind, [row]);
  }

  Future<Trip> tripRow(String id) =>
      (db.select(db.trips)..where((t) => t.id.equals(id))).getSingle();

  setUp(() async {
    db = await setUpTestDatabase();
    shares = ItemSharesRepository();
    await seedDivers(db, ['daughter', 'son', 'other', 'parent']);
    await db.customStatement(
      "UPDATE divers SET is_default = 1 WHERE id = 'daughter'",
    );
  });

  tearDown(tearDownTestDatabase);

  test('a trip shared with two children goes to the earlier share and the '
      'other child keeps access', () async {
    await seedTrip(db, 'bonaire', owner: 'parent');
    await shareWith(SharedItemKind.trip, 'bonaire', 'other', 20);
    await shareWith(SharedItemKind.trip, 'bonaire', 'son', 10);
    await seedDive(db, 'son-dive', diver: 'son', tripId: 'bonaire');
    await seedDive(db, 'other-dive', diver: 'other', tripId: 'bonaire');

    await DiverRepository().deleteDiverWithReassignment('parent');

    final trip = await tripRow('bonaire');
    expect(trip.diverId, 'son');
    expect(trip.isShared, isFalse);
    expect(
      await shares.sharingOf(SharedItemKind.trip, 'bonaire'),
      const ItemSharing(profileIds: {'other'}),
    );
    final dives = await db.select(db.dives).get();
    expect(dives.map((d) => d.tripId), everyElement('bonaire'));
    expect(await tombstoneCount(db, 'trips'), 0);
    expect(await tombstoneCount(db, ItemSharesRepository.tripEntity), 1);
    expect(await pendingCount(db, 'trips', 'bonaire'), 1);
  });

  test('a site shared with one child goes to that child', () async {
    await seedSite(db, 'pier', owner: 'parent');
    await shareWith(SharedItemKind.site, 'pier', 'son', 10);

    await DiverRepository().deleteDiverWithReassignment('parent');

    final site = await (db.select(
      db.diveSites,
    )..where((t) => t.id.equals('pier'))).getSingle();
    expect(site.diverId, 'son');
    expect(await db.select(db.siteShares).get(), isEmpty);
  });

  test('the heir of a handed-over trip loses its own hide of it', () async {
    await seedTrip(db, 'bonaire', owner: 'parent');
    await shareWith(SharedItemKind.trip, 'bonaire', 'son', 10);
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

    await DiverRepository().deleteDiverWithReassignment('parent');

    expect(await db.select(db.tripHides).get(), isEmpty);
  });

  test('the heir of an Everyone trip loses its stale share row', () async {
    await seedTrip(db, 'everyone', owner: 'parent', shared: true);
    await shareWith(SharedItemKind.trip, 'everyone', 'daughter', 10);

    await DiverRepository().deleteDiverWithReassignment('parent');

    expect((await tripRow('everyone')).diverId, 'daughter');
    expect(await db.select(db.tripShares).get(), isEmpty);
  });

  test('a private trip with no shares is still deleted', () async {
    await seedTrip(db, 'mine', owner: 'parent');

    await DiverRepository().deleteDiverWithReassignment('parent');

    expect(
      await (db.select(db.trips)..where((t) => t.id.equals('mine'))).get(),
      isEmpty,
    );
  });

  test('deleting a profile tombstones the shares naming it', () async {
    await seedTrip(db, 'daughters', owner: 'daughter');
    await seedSite(db, 'reef', owner: 'daughter');
    await shareWith(SharedItemKind.trip, 'daughters', 'parent', 10);
    await shareWith(SharedItemKind.site, 'reef', 'parent', 10);

    await DiverRepository().deleteDiverWithReassignment('parent');

    expect(await db.select(db.tripShares).get(), isEmpty);
    expect(await db.select(db.siteShares).get(), isEmpty);
    expect(await tombstoneCount(db, ItemSharesRepository.tripEntity), 1);
    expect(await tombstoneCount(db, ItemSharesRepository.siteEntity), 1);
  });

  test(
    'an Everyone trip and a trip shared with the son both survive',
    () async {
      await seedTrip(db, 'everyone', owner: 'parent', shared: true);
      await seedTrip(db, 'withSon', owner: 'parent');
      await shareWith(SharedItemKind.trip, 'withSon', 'son', 10);

      final result = await DiverRepository().deleteDiverWithReassignment(
        'parent',
      );

      expect((await tripRow('everyone')).diverId, 'daughter');
      expect((await tripRow('withSon')).diverId, 'son');
      // The message names the Everyone heir, so it counts her items only.
      expect(result.reassignedTripsCount, 1);
      expect(result.reassignedToDiverId, 'daughter');
      expect(result.handedOverCount, 1);
    },
  );
}
