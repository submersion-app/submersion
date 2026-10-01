import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Only a shared site's owner destroys, merges away or re-shares it
/// (issue #2594).
void main() {
  late AppDatabase db;
  late SiteRepository sites;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
    await seedDivers(db, ['a', 'b']);
    await seedSite(db, 'theirs', owner: 'a', shared: true);
    await seedSite(db, 'mine', owner: 'b', shared: true);
    await seedDive(db, 'b1', diver: 'b', siteId: 'theirs');
  });

  tearDown(tearDownTestDatabase);

  test('a non-owner cannot delete it', () async {
    expect(await sites.deleteSite('theirs', actingDiverId: 'b'), isFalse);
    expect(await sites.getSiteById('theirs'), isNotNull);
  });

  test('the owner deletes it and every profile\'s hide', () async {
    await ProfileHidesRepository().hide(SharedItemKind.site, 'theirs', 'b');
    expect(await sites.deleteSite('theirs', actingDiverId: 'a'), isTrue);
    expect(await sites.getSiteById('theirs'), isNull);
    expect(await db.select(db.siteHides).get(), isEmpty);
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 1);
  });

  test('a site already gone counts as deleted, not as refused', () async {
    expect(await sites.deleteSite('nope', actingDiverId: 'b'), isTrue);
    // Nothing to delete, so nothing to tell the peers either.
    expect(await tombstoneCount(db, 'diveSites'), 0);
  });

  test(
    'merge with a duplicate that is gone still reports it missing',
    () async {
      final survivor = (await sites.getSiteById('mine'))!;
      await expectLater(
        sites.mergeSites(
          mergedSite: survivor,
          siteIds: ['mine', 'gone'],
          actingDiverId: 'b',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('a caller naming no profile deletes as before', () async {
    expect(await sites.deleteSite('theirs'), isTrue);
  });

  test('bulk delete skips another profile\'s sites', () async {
    await sites.bulkDeleteSites(['theirs', 'mine'], actingDiverId: 'b');
    expect(await sites.getSiteById('theirs'), isNotNull);
    expect(await sites.getSiteById('mine'), isNull);
  });

  test('undoing the owner\'s bulk delete brings back every profile\'s hide '
      '(issue #2680)', () async {
    await ProfileHidesRepository().hide(SharedItemKind.site, 'theirs', 'b');
    final hide = (await db.select(db.siteHides).get()).single;
    final site = (await sites.getSiteById('theirs'))!;
    final links = await sites.bulkDeleteSites(['theirs'], actingDiverId: 'a');
    expect(links.hides.map((h) => h.id), [hide.id]);
    expect(await db.select(db.siteHides).get(), isEmpty);

    await sites.createSite(site);
    await clearPendingMarks(db);
    await sites.restoreSiteLinks(links);
    final back = (await db.select(db.siteHides).get()).single;
    expect((back.id, back.siteId, back.diverId), (hide.id, 'theirs', 'b'));
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 0);
    expect(
      await pendingCount(db, ProfileHidesRepository.siteEntity, hide.id),
      1,
    );
  });

  test('undoing the owner\'s merge brings back every profile\'s hide of a '
      'merged-away site (issue #2710)', () async {
    await seedSite(db, 'dup', owner: 'a', shared: true);
    await ProfileHidesRepository().hide(SharedItemKind.site, 'dup', 'b');
    final hide = (await db.select(db.siteHides).get()).single;
    final survivor = (await sites.getSiteById('theirs'))!;
    final snapshot = await sites.mergeSites(
      mergedSite: survivor,
      siteIds: ['theirs', 'dup'],
      actingDiverId: 'a',
    );
    expect(snapshot!.deletedHides.map((h) => h.id), [hide.id]);
    expect(await db.select(db.siteHides).get(), isEmpty);

    await sites.undoMerge(snapshot);
    final back = (await db.select(db.siteHides).get()).single;
    expect((back.id, back.siteId, back.diverId), (hide.id, 'dup', 'b'));
    expect(await tombstoneCount(db, ProfileHidesRepository.siteEntity), 0);
  });

  test('merge refuses another profile\'s duplicate', () async {
    final survivor = (await sites.getSiteById('mine'))!;
    final snapshot = await sites.mergeSites(
      mergedSite: survivor,
      siteIds: ['mine', 'theirs'],
      actingDiverId: 'b',
    );
    expect(snapshot, isNull);
    expect(await sites.getSiteById('theirs'), isNotNull);
  });

  test('merge keeps another profile\'s survivor, owner and sharing', () async {
    final survivor = (await sites.getSiteById('theirs'))!;
    final snapshot = await sites.mergeSites(
      mergedSite: survivor.copyWith(isShared: false, diverId: 'b'),
      siteIds: ['theirs', 'mine'],
      actingDiverId: 'b',
    );
    expect(snapshot, isNotNull);
    expect(await sites.getSiteById('mine'), isNull);
    final kept = (await sites.getSiteById('theirs'))!;
    expect((kept.diverId, kept.isShared), ('a', true));
  });

  test('a non-owner\'s save cannot unshare it', () async {
    final site = (await sites.getSiteById('theirs'))!;
    await sites.updateSite(
      site.copyWith(name: 'Renamed', isShared: false),
      actingDiverId: 'b',
    );
    final saved = (await sites.getSiteById('theirs'))!;
    expect((saved.name, saved.isShared), ('Renamed', true));
  });

  test('the owner\'s save unshares it', () async {
    final site = (await sites.getSiteById('theirs'))!;
    await sites.updateSite(site.copyWith(isShared: false), actingDiverId: 'a');
    expect((await sites.getSiteById('theirs'))!.isShared, isFalse);
  });

  test('setShared refuses a non-owner', () async {
    expect(await sites.setShared('theirs', false, actingDiverId: 'b'), isFalse);
    expect((await sites.getSiteById('theirs'))!.isShared, isTrue);
  });
}
