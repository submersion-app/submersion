import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  const t = kSeedTime;

  Future<void> site(
    String id,
    String? owner, {
    bool shared = false,
    String? library,
  }) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: id,
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
          isShared: Value(shared),
          sharedLibraryId: Value(library),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    await site('mine', kDiverA);
    await site('theirs', kDiverB);
    await site('open', kDiverB, shared: true);
    await site('named', kDiverB);
    await site('library', null, library: 'lib');
    await db
        .into(db.siteShares)
        .insert(
          SiteSharesCompanion.insert(
            id: 'share',
            siteId: 'named',
            diverId: kDiverA,
            createdAt: t,
          ),
        );
    for (final (id, siteId) in [
      ('f-mine', 'mine'),
      ('f-theirs', 'theirs'),
      ('f-open', 'open'),
    ]) {
      await db
          .into(db.siteFeatures)
          .insert(
            SiteFeaturesCompanion.insert(
              id: id,
              siteId: siteId,
              type: 'mooring',
              latitude: 1,
              longitude: 2,
              depthMeters: const Value(12),
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final (id, owner) in [('c-mine', kDiverA), ('c-theirs', kDiverB)]) {
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
      await db
          .into(db.diveCenterGearNotes)
          .insert(
            DiveCenterGearNotesCompanion.insert(
              id: 'n-$id',
              diveCenterId: id,
              gearType: 'wetsuit',
              verdict: 'good',
              notedAt: t,
              createdAt: t,
              updatedAt: t,
              leadAdjustmentKg: const Value(2),
            ),
          );
    }
    await db
        .into(db.siteTypes)
        .insert(
          SiteTypesCompanion.insert(
            id: 'custom-type',
            name: 'Custom',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverB),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  group('sites', () {
    test('a site carries metric keys and its location', () async {
      await (db.update(db.diveSites)..where((s) => s.id.equals('mine'))).write(
        const DiveSitesCompanion(
          latitude: Value(10.5),
          longitude: Value(20.5),
          minDepth: Value(5),
          maxDepth: Value(30),
        ),
      );
      final doc = (await h.one('sites', 'mine'))!;
      expect(doc['latitude'], 10.5);
      expect(doc['longitude'], 20.5);
      expect(doc['min_depth_m'], 5.0);
      expect(doc['max_depth_m'], 30.0);
      expect(doc.keys, isNot(contains('location')));
    });

    test('another profile\'s private site is missing', () async {
      expect(await h.one('sites', 'theirs'), isNull);
    });

    test('a shared site reads for every profile', () async {
      expect(await h.one('sites', 'open'), isNotNull);
    });

    test('a share row reads for the profile it names', () async {
      expect(await h.one('sites', 'named'), isNotNull);
    });

    test('a shared library site reads for a member only', () async {
      await db
          .into(db.sharedLibraryMemberships)
          .insert(
            SharedLibraryMembershipsCompanion.insert(
              id: 'member',
              diverId: kDiverA,
              libraryId: 'lib',
              memberId: 'm',
              displayName: 'A',
              libraryName: 'Lib',
              backendKind: 'folder',
              createdAt: t,
              updatedAt: t,
            ),
          );
      expect(await h.one('sites', 'library'), isNotNull);
      expect(await h.one('sites', 'library', diverId: kDiverB), isNull);
    });

    test('a hidden site hides its children', () async {
      expect(await h.one('site_features', 'f-open'), isNotNull);
      await db
          .into(db.siteHides)
          .insert(
            SiteHidesCompanion.insert(
              id: 'hide',
              siteId: 'open',
              diverId: kDiverA,
              createdAt: t,
            ),
          );
      expect(await h.one('sites', 'open'), isNull);
      expect(await h.one('site_features', 'f-open'), isNull);
      expect(await h.list('site_features'), ['f-mine']);
    });

    test('blocks arrive when named', () async {
      final doc = (await h.one(
        'sites',
        'mine',
        include: ['features', 'types', 'tags', 'species', 'media', 'shares'],
      ))!;
      expect((doc['features'] as List).cast<Map>().single['id'], 'f-mine');
      expect(doc['types'], isEmpty);
      expect(doc['tags'], isEmpty);
      expect(doc['species'], isEmpty);
      expect(doc['media'], isEmpty);
      expect(doc['shares'], isEmpty);
    });

    test('the media block follows the media rule', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'b-dive',
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
              diverId: const Value(kDiverB),
            ),
          );
      for (final (id, dive) in [('hidden', 'b-dive'), ('plain', null)]) {
        await db
            .into(db.media)
            .insert(
              MediaCompanion.insert(
                id: id,
                filePath: 'path/$id.jpg',
                siteId: const Value('open'),
                diveId: Value(dive),
                takenAt: const Value(t),
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      final doc = (await h.one('sites', 'open', include: ['media']))!;
      expect((doc['media'] as List).cast<Map>().map((m) => m['id']), ['plain']);
    });

    test('shares names the profiles a site is shared with', () async {
      final doc = (await h.one(
        'sites',
        'named',
        diverId: kDiverB,
        include: ['shares'],
      ))!;
      expect(doc['shares'], [kDiverA]);
    });

    test('scope matches getAllSites', () async {
      final expected = {
        for (final s in await SiteRepository().getAllSites(diverId: kDiverA))
          s.id,
      };
      final out = await h.get('sites', [
        'mine',
        'theirs',
        'open',
        'named',
        'library',
      ]);
      expect(
        (out['records'] as List).cast<Map>().map((r) => r['id']).toSet(),
        expected,
      );
    });
  });

  group('site_features', () {
    test('site_features list by parent', () async {
      expect(await h.list('site_features', parentId: 'open'), ['f-open']);
      expect(await h.list('site_features', parentId: 'theirs'), isEmpty);
    });

    test('a feature carries depth_m and its site', () async {
      final doc = (await h.one('site_features', 'f-mine'))!;
      expect(doc['site_id'], 'mine');
      expect(doc['depth_m'], 12.0);
      expect(doc['type'], 'mooring');
    });
  });

  group('site_types', () {
    test('scope matches getAllSiteTypes', () async {
      final expected = {
        for (final s in await SiteTypeRepository().getAllSiteTypes(
          diverId: kDiverA,
        ))
          s.id,
      };
      expect((await h.list('site_types')).toSet(), expected);
    });

    test('a custom type reads only for its owner', () async {
      expect(await h.one('site_types', 'custom-type'), isNull);
      expect(
        await h.one('site_types', 'custom-type', diverId: kDiverB),
        isNotNull,
      );
    });
  });

  group('centers', () {
    test('center gear notes follow their center', () async {
      final doc = (await h.one('center_gear_notes', 'n-c-mine'))!;
      expect(doc['center_id'], 'c-mine');
      expect(doc['lead_adjustment_kg'], 2.0);
      expect(await h.one('center_gear_notes', 'n-c-theirs'), isNull);
      expect(await h.list('center_gear_notes'), ['n-c-mine']);
      expect(await h.list('center_gear_notes', parentId: 'c-mine'), [
        'n-c-mine',
      ]);
    });

    test('the gear_notes block lists them', () async {
      final doc = (await h.one('centers', 'c-mine', include: ['gear_notes']))!;
      expect((doc['gear_notes'] as List).cast<Map>().single['id'], 'n-c-mine');
    });

    test('a center keeps its address and contact details', () async {
      await (db.update(
        db.diveCenters,
      )..where((c) => c.id.equals('c-mine'))).write(
        const DiveCentersCompanion(
          phone: Value('+1 555'),
          email: Value('c@example.com'),
        ),
      );
      final doc = (await h.one('centers', 'c-mine'))!;
      expect(doc['phone'], '+1 555');
      expect(doc['email'], 'c@example.com');
    });

    test('scope matches getAllDiveCenters', () async {
      final expected = {
        for (final c in await DiveCenterRepository().getAllDiveCenters(
          diverId: kDiverA,
        ))
          c.id,
      };
      final out = await h.get('centers', ['c-mine', 'c-theirs']);
      expect(
        (out['records'] as List).cast<Map>().map((r) => r['id']).toSet(),
        expected,
      );
    });
  });
}
