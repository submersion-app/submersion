import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// A site one profile hides leaves that profile's lists only (issue #2594).
void main() {
  late AppDatabase db;
  late SiteRepository sites;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
    await seedDivers(db, ['a', 'b', 'c']);
    await seedSite(db, 'pier', owner: 'a', shared: true, name: 'Salt Pier');
    await ProfileHidesRepository().hide(SharedItemKind.site, 'pier', 'b');
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> visibleTo(String diverId) async => [
    for (final s in await sites.getAllSites(diverId: diverId)) s.id,
  ];

  test('getAllSites hides it from b, not from a or c', () async {
    expect(await visibleTo('b'), isEmpty);
    expect(await visibleTo('a'), ['pier']);
    expect(await visibleTo('c'), ['pier']);
  });

  test('searchSites hides it from b', () async {
    expect(await sites.searchSites('salt', diverId: 'b'), isEmpty);
    expect(await sites.searchSites('salt', diverId: 'c'), hasLength(1));
  });

  test('a lookup by id still finds it', () async {
    expect((await sites.getSiteById('pier'))?.name, 'Salt Pier');
  });

  test('the site-type count leaves it out for b only', () async {
    final typeId =
        (await db
                .customSelect(
                  'SELECT id FROM site_types WHERE is_built_in = 1 LIMIT 1',
                )
                .getSingle())
            .read<String>('id');
    await db.customStatement(
      'INSERT INTO site_site_types (id, site_id, site_type_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      ['sst', 'pier', typeId, kSharedTs],
    );
    Future<int> countFor(String diverId) async =>
        (await SiteTypeRepository().getSiteTypeStatistics(
          diverId: diverId,
        )).firstWhere((s) => s.siteType.id == typeId).siteCount;
    expect(await countFor('b'), 0);
    expect(await countFor('c'), 1);
  });

  test('watchSitesChanges ticks on a hide', () async {
    await seedSite(db, 'other', owner: 'a', shared: true);
    final tick = sites.watchSitesChanges().first.timeout(
      const Duration(seconds: 5),
    );
    await ProfileHidesRepository().hide(SharedItemKind.site, 'other', 'b');
    await expectLater(tick, completes);
  });
}
