import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SiteRepository sites;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const found = PlaceLookup(
    country: 'Switzerland',
    region: 'Lucerne',
    locality: 'Weggis',
    bodyOfWater: 'Lake Lucerne',
  );

  Future<void> clearSyncRecords(String siteId) =>
      (db.delete(db.syncRecords)..where((t) => t.recordId.equals(siteId))).go();

  Future<int> pendingCount(String siteId) async => (await (db.select(
    db.syncRecords,
  )..where((t) => t.recordId.equals(siteId))).get()).length;

  test('fills only the empty columns and reports a change', () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        name: 'Hertenstein',
        country: 'Schweiz',
        rating: 4,
        location: GeoPoint(47.027631, 8.400640),
      ),
    );

    final changed = await sites.fillMissingLocationDetails('s1', found);

    expect(changed, isTrue);
    final stored = await sites.getSiteById('s1');
    expect(stored!.country, 'Schweiz', reason: 'filled values are kept');
    expect(stored.region, 'Lucerne');
    expect(stored.city, 'Weggis');
    expect(stored.bodyOfWater, 'Lake Lucerne');
    expect(stored.rating, 4, reason: 'unrelated columns untouched');
  });

  test('marks the site pending for sync when it changed', () async {
    await sites.createSite(const DiveSite(id: 's2', name: 'n'));
    await clearSyncRecords('s2');

    await sites.fillMissingLocationDetails('s2', found);

    expect(await pendingCount('s2'), greaterThan(0));
  });

  test('writes nothing and reports no change when all filled', () async {
    await sites.createSite(
      const DiveSite(
        id: 's3',
        name: 'n',
        country: 'a',
        region: 'b',
        city: 'c',
        bodyOfWater: 'd',
      ),
    );
    final before = await sites.getSiteById('s3');
    await clearSyncRecords('s3');

    final changed = await sites.fillMissingLocationDetails('s3', found);

    expect(changed, isFalse);
    expect(await sites.getSiteById('s3'), before);
    expect(await pendingCount('s3'), 0, reason: 'no write, no sync record');
  });

  test('returns false for an unknown site', () async {
    expect(await sites.fillMissingLocationDetails('nope', found), isFalse);
  });
}
