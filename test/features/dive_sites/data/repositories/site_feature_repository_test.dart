import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SiteFeatureRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = SiteFeatureRepository();
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test(
    'add / list / update / delete round-trip with the sync ritual',
    () async {
      final f = await repo.addFeature(
        siteId: 'site-1',
        typeName: 'mooring',
        latitude: 12.151,
        longitude: -68.299,
        depthMeters: 6,
      );
      expect(f.type?.name, 'mooring');

      final listed = await repo.getFeaturesForSite('site-1');
      expect(listed, hasLength(1));

      // The write ritual: the row is pending AND carries an hlc stamp.
      final row = await (db.select(
        db.siteFeatures,
      )..where((t) => t.id.equals(f.id))).getSingle();
      expect(row.hlc, isNotNull);
      final pending = await db.select(db.syncRecords).get();
      expect(pending.where((p) => p.entityType == 'siteFeatures'), isNotEmpty);
      // The parent site was bumped too.
      expect(pending.where((p) => p.entityType == 'diveSites'), isNotEmpty);

      await repo.updateFeature(f.copyWith(name: 'North ball', bearingDeg: 90));
      final updated = (await repo.getFeaturesForSite('site-1')).single;
      expect(updated.name, 'North ball');
      expect(updated.bearingDeg, 90);

      await repo.deleteFeature(f.id);
      expect(await repo.getFeaturesForSite('site-1'), isEmpty);
      final tombstones = await db.select(db.deletionLog).get();
      expect(
        tombstones.where(
          (d) => d.entityType == 'siteFeatures' && d.recordId == f.id,
        ),
        isNotEmpty,
      );
    },
  );

  test('features come back in creation order and are site-scoped', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-2',
            name: 'Other',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final first = await repo.addFeature(
      siteId: 'site-1',
      typeName: 'entry',
      latitude: 12.1,
      longitude: -68.3,
    );
    final second = await repo.addFeature(
      siteId: 'site-1',
      typeName: 'exit',
      latitude: 12.2,
      longitude: -68.4,
    );
    await repo.addFeature(
      siteId: 'site-2',
      typeName: 'hazard',
      latitude: 12.3,
      longitude: -68.5,
    );

    final forSite1 = await repo.getFeaturesForSite('site-1');
    expect(forSite1.map((f) => f.id), [first.id, second.id]);
  });
  test('getFeaturesForSites reads every site in one query', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-2',
            name: 'Lake wreck',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await repo.addFeature(
      siteId: 'site-1',
      typeName: 'mooring',
      latitude: 12.151,
      longitude: -68.299,
    );
    await repo.addFeature(
      siteId: 'site-2',
      typeName: 'wreck',
      latitude: 36.1,
      longitude: -5.6,
    );

    final bySite = await repo.getFeaturesForSites(['site-1', 'site-2']);
    expect(bySite['site-1']!.single.typeName, 'mooring');
    expect(bySite['site-2']!.single.typeName, 'wreck');
  });

  test('getFeaturesForSites omits a site with no features', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-2',
            name: 'Lake wreck',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await repo.addFeature(
      siteId: 'site-1',
      typeName: 'mooring',
      latitude: 12.151,
      longitude: -68.299,
    );

    final bySite = await repo.getFeaturesForSites(['site-1', 'site-2']);
    expect(bySite.keys, ['site-1']);
  });

  test('getFeaturesForSites returns nothing for no sites', () async {
    expect(await repo.getFeaturesForSites(const []), isEmpty);
  });
  test('getFeaturesForSites reads past SQLite\'s bound-variable limit and '
      'merges across chunks', () async {
    // One variable is bound per id, and SQLite refuses a statement past its
    // limit, so a library with enough sites would fail the export outright
    // rather than load its features. 40000 is over the limit of every
    // build: without chunking this throws "too many SQL variables".
    const count = 40000;
    final ids = [for (var i = 0; i < count; i++) 'bulk-site-$i'];
    await db.batch((batch) {
      batch.insertAll(db.diveSites, [
        for (final id in ids)
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            createdAt: 1,
            updatedAt: 1,
          ),
      ]);
    });
    // Three sites that cannot share a chunk, so a merge that kept only one
    // chunk's rows would lose two of them.
    final marked = [ids.first, ids[count ~/ 2], ids.last];
    for (final id in marked) {
      await repo.addFeature(
        siteId: id,
        typeName: 'mooring',
        latitude: 1,
        longitude: 2,
      );
    }

    final bySite = await repo.getFeaturesForSites(ids);
    expect(bySite.keys, unorderedEquals(marked));
    for (final id in marked) {
      expect(bySite[id]!.single.typeName, 'mooring');
    }
  });
}
