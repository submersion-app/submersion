import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

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

  test('isHidden answers for the hiding profile only (#2679)', () async {
    expect(
      await repository.isHidden(SharedItemKind.trip, 'shared', 'b'),
      false,
    );
    await repository.hide(SharedItemKind.trip, 'shared', 'b');
    expect(await repository.isHidden(SharedItemKind.trip, 'shared', 'b'), true);
    expect(
      await repository.isHidden(SharedItemKind.trip, 'shared', 'a'),
      false,
    );
    expect(
      await repository.isHidden(SharedItemKind.site, 'shared', 'b'),
      false,
    );
    await repository.unhide(SharedItemKind.trip, 'shared', 'b');
    expect(
      await repository.isHidden(SharedItemKind.trip, 'shared', 'b'),
      false,
    );
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

  test('deleteHides returns every hide it removed', () async {
    await seedDivers(db, ['c']);
    await repository.hide(SharedItemKind.site, 'pier', 'b');
    await repository.hide(SharedItemKind.site, 'pier', 'c');
    final rows = await db.select(db.siteHides).get();
    final removed = await db.transaction(
      () => repository.deleteHides(SharedItemKind.site, ['pier']),
    );
    expect(removed.toSet(), {
      for (final r in rows)
        (
          id: r.id,
          itemId: r.siteId,
          diverId: r.diverId,
          createdAt: r.createdAt,
        ),
    });
  });

  group('restoreHides (issue #2680)', () {
    Future<List<ProfileHide>> hideThenDelete() async {
      await repository.hide(SharedItemKind.site, 'pier', 'b');
      return db.transaction(
        () => repository.deleteHides(SharedItemKind.site, ['pier']),
      );
    }

    test('puts a removed hide back under its id, pending, and drops its '
        'tombstone', () async {
      final removed = await hideThenDelete();
      final deleteClock =
          (await db
                  .customSelect(
                    'SELECT hlc FROM deletion_log WHERE entity_type = ?',
                    variables: [
                      const Variable<String>(ProfileHidesRepository.siteEntity),
                    ],
                  )
                  .getSingle())
              .read<String>('hlc');
      await clearPendingMarks(db);
      await repository.restoreHides(SharedItemKind.site, removed);
      final row = (await db.select(db.siteHides).get()).single;
      // A peer that applied the delete revives the hide only for a clock
      // newer than the delete's (SyncService's local-deletion guard).
      expect(row.hlc!.compareTo(deleteClock), greaterThan(0));
      expect((
        id: row.id,
        itemId: row.siteId,
        diverId: row.diverId,
        createdAt: row.createdAt,
      ), removed.single);
      expect(
        await pendingCount(db, ProfileHidesRepository.siteEntity, row.id),
        1,
      );
      expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 0);
    });

    test('puts a trip hide back too', () async {
      await repository.hide(SharedItemKind.trip, 'shared', 'b');
      final removed = await db.transaction(
        () => repository.deleteHides(SharedItemKind.trip, ['shared']),
      );
      await repository.restoreHides(SharedItemKind.trip, removed);
      final row = (await db.select(db.tripHides).get()).single;
      expect(
        (row.id, row.tripId, row.diverId),
        (removed.single.id, 'shared', 'b'),
      );
      expect(await tombstoneCount(db, ProfileHidesRepository.tripEntity), 0);
    });

    test('skips a hide whose item is gone', () async {
      final removed = await hideThenDelete();
      await db.customStatement("DELETE FROM dive_sites WHERE id = 'pier'");
      await repository.restoreHides(SharedItemKind.site, removed);
      expect(await db.select(db.siteHides).get(), isEmpty);
      expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
    });

    test('skips a hide whose profile is gone', () async {
      final removed = await hideThenDelete();
      await db.customStatement("DELETE FROM divers WHERE id = 'b'");
      await repository.restoreHides(SharedItemKind.site, removed);
      expect(await db.select(db.siteHides).get(), isEmpty);
    });

    test('leaves a profile that hid the item again alone', () async {
      final removed = await hideThenDelete();
      await repository.hide(SharedItemKind.site, 'pier', 'b');
      final again = (await db.select(db.siteHides).get()).single;
      await repository.restoreHides(SharedItemKind.site, removed);
      expect((await db.select(db.siteHides).get()).single.id, again.id);
      expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
    });
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
