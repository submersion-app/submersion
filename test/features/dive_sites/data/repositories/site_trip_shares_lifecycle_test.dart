import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Share rows through an owner's deletes and site merges (issue #2151): a
/// delete tombstones them, an undo brings them back, and a merge carries a
/// merged-away site's shares onto the site that is kept.
void main() {
  late AppDatabase db;
  late SiteRepository sites;
  late ItemSharesRepository shares;

  Future<void> shareWith(SharedItemKind kind, String id, Set<String> who) =>
      shares.setSharing(
        kind,
        id,
        ItemSharing(profileIds: who),
        actingDiverId: 'me',
      );

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
    shares = ItemSharesRepository();
    await seedDivers(db, ['me', 'son', 'daughter']);
  });

  tearDown(tearDownTestDatabase);

  test('deleting a shared trip tombstones its share rows', () async {
    await seedTrip(db, 'bonaire', owner: 'me');
    await shareWith(SharedItemKind.trip, 'bonaire', {'son'});
    expect(
      await TripRepository().deleteTrip('bonaire', actingDiverId: 'me'),
      isTrue,
    );
    expect(await db.select(db.tripShares).get(), isEmpty);
    expect(await tombstoneCount(db, ItemSharesRepository.tripEntity), 1);
  });

  test('undoing a site bulk delete restores its share rows', () async {
    await seedSite(db, 'pier', owner: 'me');
    await shareWith(SharedItemKind.site, 'pier', {'son'});
    final row = (await db.select(db.siteShares).get()).single;
    final site = (await sites.getSiteById('pier'))!;

    final links = await sites.bulkDeleteSites(['pier'], actingDiverId: 'me');
    expect(links.shares.map((s) => s.id), [row.id]);
    expect(await db.select(db.siteShares).get(), isEmpty);
    expect(await tombstoneCount(db, ItemSharesRepository.siteEntity), 1);

    await sites.createSite(site);
    await sites.restoreSiteLinks(links);
    final back = (await db.select(db.siteShares).get()).single;
    expect((back.id, back.siteId, back.diverId), (row.id, 'pier', 'son'));
    expect(await tombstoneCount(db, ItemSharesRepository.siteEntity), 0);
  });

  test('merging sites carries a duplicate share onto the survivor, and undo '
      'puts it back', () async {
    await seedSite(db, 'keep', owner: 'me');
    await seedSite(db, 'dup', owner: 'me');
    await shareWith(SharedItemKind.site, 'keep', {'daughter'});
    await shareWith(SharedItemKind.site, 'dup', {'son', 'daughter'});
    final dupRows = {
      for (final r in await (db.select(
        db.siteShares,
      )..where((t) => t.siteId.equals('dup'))).get())
        r.id,
    };
    final survivor = (await sites.getSiteById('keep'))!;

    final snapshot = await sites.mergeSites(
      mergedSite: survivor,
      siteIds: ['keep', 'dup'],
      actingDiverId: 'me',
    );

    expect(
      await shares.sharingOf(SharedItemKind.site, 'keep'),
      const ItemSharing(profileIds: {'son', 'daughter'}),
    );
    expect(snapshot!.deletedShares.map((s) => s.id).toSet(), dupRows);
    expect(snapshot.createdShareIds, hasLength(1));

    await sites.undoMerge(snapshot);
    expect(
      await shares.sharingOf(SharedItemKind.site, 'keep'),
      const ItemSharing(profileIds: {'daughter'}),
    );
    expect(
      await shares.sharingOf(SharedItemKind.site, 'dup'),
      const ItemSharing(profileIds: {'son', 'daughter'}),
    );
  });

  test('merging into an Everyone survivor adds no share rows', () async {
    await seedSite(db, 'keep', owner: 'me', shared: true);
    await seedSite(db, 'dup', owner: 'me');
    await shareWith(SharedItemKind.site, 'dup', {'son'});
    final survivor = (await sites.getSiteById('keep'))!;

    final snapshot = await sites.mergeSites(
      mergedSite: survivor,
      siteIds: ['keep', 'dup'],
      actingDiverId: 'me',
    );

    expect(await db.select(db.siteShares).get(), isEmpty);
    expect(snapshot!.createdShareIds, isEmpty);
    expect(
      await shares.sharingOf(SharedItemKind.site, 'keep'),
      ItemSharing.all,
    );
  });
}
