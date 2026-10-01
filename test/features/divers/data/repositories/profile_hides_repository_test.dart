import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A profile's hidden shared trips and sites (issue #2594).
void main() {
  late AppDatabase db;
  late ProfileHidesRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = ProfileHidesRepository();
    await seedDivers(db, ['a', 'b']);
    await seedTrip(db, 'shared', owner: 'a', shared: true, name: 'Bonaire');
    await seedTrip(db, 'private', owner: 'a');
    await seedSite(db, 'pier', owner: 'a', shared: true, name: 'Salt Pier');
  });

  tearDown(tearDownTestDatabase);

  test('another profile hides a shared trip, marked pending', () async {
    expect(await repository.hide(SharedItemKind.trip, 'shared', 'b'), isTrue);
    final row = (await db.select(db.tripHides).get()).single;
    expect((row.tripId, row.diverId), ('shared', 'b'));
    expect(
      await pendingCount(db, ProfileHidesRepository.tripEntity, row.id),
      1,
    );
  });

  test('hiding twice keeps one row', () async {
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    expect(await repository.hide(SharedItemKind.trip, 'shared', 'b'), isTrue);
    expect(await db.select(db.tripHides).get(), hasLength(1));
  });

  test('the owner, an unshared trip and a missing trip are refused', () async {
    expect(await repository.hide(SharedItemKind.trip, 'shared', 'a'), isFalse);
    expect(await repository.hide(SharedItemKind.trip, 'private', 'b'), isFalse);
    expect(await repository.hide(SharedItemKind.trip, 'nope', 'b'), isFalse);
    expect(await db.select(db.tripHides).get(), isEmpty);
  });

  test('hideAll hides a batch in one go and counts what is hidden', () async {
    await seedTrip(db, 'shared2', owner: 'a', shared: true);
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    final hidden = await repository.hideAll(SharedItemKind.trip, [
      'shared',
      'shared2',
      'private',
      'nope',
    ], 'b');
    // 'shared' was already hidden, 'shared2' is new; the unshared and the
    // missing trip are refused.
    expect(hidden, 2);
    expect((await db.select(db.tripHides).get()).map((h) => h.tripId).toSet(), {
      'shared',
      'shared2',
    });
  });

  test('unhide deletes and tombstones the row', () async {
    await repository.hide(SharedItemKind.site, 'pier', 'b');
    await repository.unhide(SharedItemKind.site, 'pier', 'b');
    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
  });

  test('hiddenItems lists the profile\'s trips then sites', () async {
    await repository.hide(SharedItemKind.site, 'pier', 'b');
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    final items = await repository.hiddenItems('b');
    expect(items.map((i) => (i.kind, i.id, i.name, i.ownerId)), [
      (SharedItemKind.trip, 'shared', 'Bonaire', 'a'),
      (SharedItemKind.site, 'pier', 'Salt Pier', 'a'),
    ]);
    expect(await repository.hiddenItems('a'), isEmpty);
  });

  group('an item its owner unshares (issue #2678)', () {
    Future<void> unshare({required bool shared}) async {
      expect(
        await TripRepository().setShared('shared', shared, actingDiverId: 'a'),
        isTrue,
      );
      expect(
        await SiteRepository().setShared('pier', shared, actingDiverId: 'a'),
        isTrue,
      );
    }

    setUp(() async {
      await repository.hide(SharedItemKind.trip, 'shared', 'b');
      await repository.hide(SharedItemKind.site, 'pier', 'b');
    });

    test('drops out of hiddenItems; its hides stay', () async {
      await unshare(shared: false);

      expect(await repository.hiddenItems('b'), isEmpty);
      expect(await db.select(db.tripHides).get(), hasLength(1));
      expect(await db.select(db.siteHides).get(), hasLength(1));
    });

    test('is listed, still hidden, once re-shared', () async {
      await unshare(shared: false);
      await unshare(shared: true);

      expect((await repository.hiddenItems('b')).map((i) => i.id), [
        'shared',
        'pier',
      ]);
    });
  });

  test('hiddenItems keeps a hide that hides an item from its owner', () async {
    // Only sync can leave this: a hide written on one device lands after
    // another device reassigned the item to the hiding profile. The hide
    // still keeps the item from its owner, so Unhide must stay reachable.
    await db.customStatement(
      "INSERT INTO trip_hides (id, trip_id, diver_id, created_at) "
      "VALUES ('h1', 'private', 'a', $kSharedTs)",
    );

    expect((await repository.hiddenItems('a')).single.id, 'private');
  });

  test('deleteHides removes every profile\'s hides of an item', () async {
    await seedDivers(db, ['c']);
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    await repository.hide(SharedItemKind.trip, 'shared', 'c');
    await db.transaction(
      () => repository.deleteHides(SharedItemKind.trip, ['shared']),
    );
    expect(await db.select(db.tripHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.tripEntity), 2);
  });

  test('deleteHides with a diverId removes only that profile\'s', () async {
    await seedDivers(db, ['c']);
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    await repository.hide(SharedItemKind.trip, 'shared', 'c');
    await db.transaction(
      () =>
          repository.deleteHides(SharedItemKind.trip, ['shared'], diverId: 'c'),
    );
    expect((await db.select(db.tripHides).get()).single.diverId, 'b');
  });

  test('diveLinkCounts splits the item\'s dives by profile', () async {
    await seedDive(db, 'a1', diver: 'a', tripId: 'shared', siteId: 'pier');
    await seedDive(db, 'b1', diver: 'b', tripId: 'shared');
    await seedDive(db, 'b2', diver: 'b', tripId: 'shared', siteId: 'pier');
    expect(
      await repository.diveLinkCounts(SharedItemKind.trip, 'shared', 'b'),
      (mine: 2, others: 1),
    );
    expect(await repository.diveLinkCounts(SharedItemKind.site, 'pier', 'a'), (
      mine: 1,
      others: 1,
    ));
    expect(await repository.diveLinkCounts(SharedItemKind.site, 'none', 'a'), (
      mine: 0,
      others: 0,
    ));
  });

  test('watchChanges emits on a hide', () async {
    final tick = repository.watchChanges().first.timeout(
      const Duration(seconds: 5),
    );
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    await expectLater(tick, completes);
  });
}
