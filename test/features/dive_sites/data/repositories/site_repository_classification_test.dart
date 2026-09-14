import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';

import '../../../../helpers/test_database.dart';

/// Site types and tags written and read with the site (issue #1765).
void main() {
  late SiteRepository sites;
  late SiteClassificationRepository classification;

  Future<void> seedTag() => DatabaseService.instance.database.customStatement(
    "INSERT INTO tags (id, name, created_at, updated_at, "
    "applies_to_dives, applies_to_sites) "
    "VALUES ('t1', 'To try', 0, 0, 0, 1)",
  );

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
    classification = SiteClassificationRepository();
    await seedTag();
  });

  tearDown(() async => tearDownTestDatabase());

  List<String> typeIds(Iterable<dynamic> types) => [
    for (final t in types) t.id as String,
  ];

  test('createSite writes the classification with the row', () async {
    final site = await sites.createSite(
      const DiveSite(id: '', name: 'Lake wreck'),
      classification: const SiteClassification(
        typeIds: ['wreck', 'lake'],
        tagIds: ['t1'],
      ),
    );

    expect(typeIds(await classification.getTypesForSite(site.id)), [
      'wreck',
      'lake',
    ]);
    expect((await classification.getTagsForSite(site.id)).single.id, 't1');
  });

  test('updateSite with a classification replaces the sets', () async {
    final site = await sites.createSite(
      const DiveSite(id: '', name: 'Reef'),
      classification: const SiteClassification(
        typeIds: ['reef'],
        tagIds: ['t1'],
      ),
    );

    await sites.updateSite(
      site,
      classification: const SiteClassification(typeIds: ['wall']),
    );

    expect(typeIds(await classification.getTypesForSite(site.id)), ['wall']);
    expect(await classification.getTagsForSite(site.id), isEmpty);
  });

  group('a save that changes only types or tags (#1769)', () {
    final db = DatabaseService.instance;

    Future<int> storedUpdatedAt(String id) async =>
        (await db.database
                .customSelect(
                  'SELECT updated_at FROM dive_sites WHERE id = ?',
                  variables: [Variable.withString(id)],
                )
                .getSingle())
            .read<int>('updated_at');

    Future<bool> sitePending(String id) async =>
        (await db.database
                .customSelect(
                  "SELECT 1 FROM sync_records "
                  "WHERE entity_type = 'diveSites' AND record_id = ?",
                  variables: [Variable.withString(id)],
                )
                .get())
            .isNotEmpty;

    Future<DiveSite> freshSite() async {
      final site = await sites.createSite(
        const DiveSite(id: '', name: 'Reef'),
        classification: const SiteClassification(typeIds: ['reef']),
      );
      await db.database.customStatement(
        'UPDATE dive_sites SET updated_at = 5 WHERE id = ?',
        [site.id],
      );
      await db.database.customStatement('DELETE FROM sync_records');
      return site;
    }

    test('leaves the site row unstamped and not pending', () async {
      final site = await freshSite();

      await sites.updateSite(
        site,
        classification: const SiteClassification(typeIds: ['wall']),
      );

      expect(typeIds(await classification.getTypesForSite(site.id)), ['wall']);
      expect(await storedUpdatedAt(site.id), 5);
      expect(await sitePending(site.id), isFalse);
    });

    test('still stamps the site when one of its fields changed', () async {
      final site = await freshSite();

      await sites.updateSite(
        site.copyWith(name: 'Reef renamed'),
        classification: const SiteClassification(typeIds: ['wall']),
      );

      expect(await storedUpdatedAt(site.id), isNot(5));
      expect(await sitePending(site.id), isTrue);
    });
  });

  test(
    'updateSite without a classification leaves the junctions (#1187)',
    () async {
      final site = await sites.createSite(
        const DiveSite(id: '', name: 'Reef'),
        classification: const SiteClassification(
          typeIds: ['reef'],
          tagIds: ['t1'],
        ),
      );

      // A partially loaded entity, as the dive hydration and importers build.
      await sites.updateSite(DiveSite(id: site.id, name: 'Reef renamed'));

      expect(typeIds(await classification.getTypesForSite(site.id)), ['reef']);
      expect(await classification.getTagsForSite(site.id), hasLength(1));
    },
  );

  test('a failing classification write rolls back the site row', () async {
    await expectLater(
      sites.createSite(
        const DiveSite(id: 'fixed', name: 'Doomed'),
        // A tag id with no tags row violates the site_tags foreign key.
        classification: const SiteClassification(tagIds: ['missing']),
      ),
      throwsA(anything),
    );
    expect(await sites.getSiteById('fixed'), isNull);
  });

  test('mergeSites unions types and tags; undo restores each site', () async {
    final a = await sites.createSite(
      const DiveSite(id: '', name: 'A'),
      classification: const SiteClassification(typeIds: ['wreck']),
    );
    final b = await sites.createSite(
      const DiveSite(id: '', name: 'B'),
      classification: const SiteClassification(
        typeIds: ['lake'],
        tagIds: ['t1'],
      ),
    );

    final snapshot = await sites.mergeSites(
      mergedSite: a,
      siteIds: [a.id, b.id],
    );

    expect(typeIds(await classification.getTypesForSite(a.id)).toSet(), {
      'wreck',
      'lake',
    });
    expect((await classification.getTagsForSite(a.id)).single.id, 't1');

    await sites.undoMerge(snapshot!);

    expect(typeIds(await classification.getTypesForSite(a.id)), ['wreck']);
    expect(await classification.getTagsForSite(a.id), isEmpty);
    expect(typeIds(await classification.getTypesForSite(b.id)), ['lake']);
    expect((await classification.getTagsForSite(b.id)).single.id, 't1');
  });

  test('the site list carries types and tags', () async {
    await sites.createSite(
      const DiveSite(id: '', name: 'Typed'),
      classification: const SiteClassification(
        typeIds: ['cave'],
        tagIds: ['t1'],
      ),
    );
    await sites.createSite(const DiveSite(id: '', name: 'Bare'));

    final list = await sites.getSitesWithDiveCounts();
    final typed = list.singleWhere((e) => e.site.name == 'Typed');
    final bare = list.singleWhere((e) => e.site.name == 'Bare');
    expect(typeIds(typed.siteTypes), ['cave']);
    expect(typed.tags.map((t) => t.name), ['To try']);
    expect(bare.siteTypes, isEmpty);
    expect(bare.tags, isEmpty);
  });

  test(
    'the site list statement count does not grow with the site count',
    () async {
      await tearDownTestDatabase();
      DatabaseService.instance.setTestDatabase(
        AppDatabase(NativeDatabase.memory(logStatements: true)),
      );
      sites = SiteRepository();
      await seedTag();

      Future<int> countStatements() async {
        final logged = <String>[];
        await runZoned(
          () => sites.getSitesWithDiveCounts(),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => logged.add(line),
          ),
        );
        return logged.length;
      }

      Future<void> addSite(String name) => sites.createSite(
        DiveSite(id: '', name: name),
        classification: const SiteClassification(
          typeIds: ['wreck'],
          tagIds: ['t1'],
        ),
      );

      // Fixtures are written OUTSIDE the zone so their writes are not counted.
      await addSite('One');
      final one = await countStatements();
      for (var i = 0; i < 5; i++) {
        await addSite('More $i');
      }
      final six = await countStatements();

      expect(one, greaterThan(0));
      expect(six, one);
    },
  );
}
