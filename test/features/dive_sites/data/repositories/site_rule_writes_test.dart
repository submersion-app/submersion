import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// The site writes logbook rules need (#3513): remove tags and types, and
/// append to a description.
void main() {
  late SiteClassificationRepository classification;

  setUp(() async {
    await setUpTestDatabase();
    classification = SiteClassificationRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, description, created_at, updated_at) "
      "VALUES ('s1', 'A', '', 0, 0), ('s2', 'B', 'Reef', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'To try', 0, 0, 0, 1), ('t2', 'Avoid', 0, 0, 0, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<int> count(String sql) async {
    final row = await DatabaseService.instance.database
        .customSelect(sql)
        .getSingle();
    return row.read<int>('n');
  }

  test('removeTags removes only the named tags and tombstones them', () async {
    await classification.replaceTags('s1', ['t1', 't2']);
    await classification.removeTags('s1', ['t1']);
    final tags = await classification.getTagsForSite('s1');
    expect(tags.map((t) => t.id), ['t2']);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = 'siteTags'",
      ),
      1,
    );
  });

  test('removeTags on a site without the tag is a no-op', () async {
    await classification.replaceTags('s1', ['t2']);
    await classification.removeTags('s1', ['t1']);
    expect((await classification.getTagsForSite('s1')).map((t) => t.id), [
      't2',
    ]);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = 'siteTags'",
      ),
      0,
    );
  });

  test(
    'removeTypes removes only the named types and tombstones them',
    () async {
      await classification.replaceTypes('s1', ['wreck', 'lake']);
      await classification.removeTypes('s1', ['wreck']);
      final types = await classification.getTypesForSite('s1');
      expect(types.map((t) => t.id), ['lake']);
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'siteSiteTypes'",
        ),
        1,
      );
    },
  );

  test('removeTypes of an absent type is a no-op', () async {
    await classification.replaceTypes('s1', ['lake']);
    await classification.removeTypes('s1', ['wreck']);
    expect((await classification.getTypesForSite('s1')).map((t) => t.id), [
      'lake',
    ]);
  });

  group('writes over many sites', () {
    Future<List<String>> strings(String sql) async => [
      for (final r
          in await DatabaseService.instance.database.customSelect(sql).get())
        r.data.values.first! as String,
    ];

    test('addTagsToSites keeps each site\'s tags in the given order', () async {
      await classification.addTagsToSites({
        's1': ['t2', 't1'],
        's2': ['t1'],
      });
      expect(
        await strings(
          "SELECT tag_id FROM site_tags WHERE site_id = 's1' "
          'ORDER BY created_at, id',
        ),
        ['t2', 't1'],
      );
      expect((await classification.getTagIdsBySite(['s2']))['s2'], ['t1']);
    });

    test('addTagsToSites marks each new link pending with a clock', () async {
      await classification.addTagsToSites({
        's1': ['t1'],
        's2': ['t1'],
      });
      final links = await strings('SELECT id FROM site_tags ORDER BY id');
      expect(links, hasLength(2));
      expect(
        await strings(
          "SELECT record_id FROM sync_records "
          "WHERE entity_type = 'siteTags' AND sync_status = 'pending' "
          'ORDER BY record_id',
        ),
        links,
      );
      expect(
        await count('SELECT COUNT(*) AS n FROM site_tags WHERE hlc IS NULL'),
        0,
      );
    });

    test('addTagsToSites leaves a pair already held alone', () async {
      await classification.replaceTags('s1', ['t1']);
      final held = await strings('SELECT id FROM site_tags');
      await DatabaseService.instance.database.customStatement(
        'DELETE FROM sync_records',
      );

      await classification.addTagsToSites({
        's1': ['t1', 't2'],
      });

      expect(await strings('SELECT id FROM site_tags'), contains(held.single));
      expect(await count('SELECT COUNT(*) AS n FROM site_tags'), 2);
      expect(
        await strings('SELECT record_id FROM sync_records'),
        isNot(contains(held.single)),
      );
      expect(await count('SELECT COUNT(*) AS n FROM sync_records'), 1);
    });

    test('addTypesToSites marks each new link pending', () async {
      await classification.addTypesToSites({
        's1': ['wreck', 'lake'],
        's2': ['lake'],
      });
      expect(
        await strings(
          "SELECT site_type_id FROM site_site_types WHERE site_id = 's1' "
          'ORDER BY created_at, id',
        ),
        ['wreck', 'lake'],
      );
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM sync_records "
          "WHERE entity_type = 'siteSiteTypes'",
        ),
        3,
      );
    });

    test('removeTagsFromSites tombstones only the rows that went', () async {
      await classification.replaceTags('s1', ['t1', 't2']);
      await classification.replaceTags('s2', ['t2']);
      final gone = await strings(
        "SELECT id FROM site_tags WHERE tag_id = 't1'",
      );

      await classification.removeTagsFromSites(['s1', 's2'], ['t1']);

      expect((await classification.getTagIdsBySite(['s1']))['s1'], ['t2']);
      expect((await classification.getTagIdsBySite(['s2']))['s2'], ['t2']);
      expect(
        await strings(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'siteTags'",
        ),
        gone,
      );
    });

    test('removeTypesFromSites tombstones only the rows that went', () async {
      await classification.replaceTypes('s1', ['wreck', 'lake']);
      await classification.replaceTypes('s2', ['lake']);

      await classification.removeTypesFromSites(['s1', 's2'], ['wreck']);

      expect((await classification.getTypeIdsBySite(['s1']))['s1'], ['lake']);
      expect((await classification.getTypeIdsBySite(['s2']))['s2'], ['lake']);
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'siteSiteTypes'",
        ),
        1,
      );
    });

    test('nothing to write opens nothing', () async {
      await classification.addTagsToSites({});
      await classification.removeTagsFromSites([], ['t1']);
      await classification.removeTagsFromSites(['s1'], []);
      expect(await count('SELECT COUNT(*) AS n FROM sync_records'), 0);
      expect(await count('SELECT COUNT(*) AS n FROM deletion_log'), 0);
    });
  });

  test(
    'appendDescriptionToAll adds a blank line only after existing text',
    () async {
      final sites = SiteRepository();
      await sites.appendDescriptionToAll(['s1', 's2'], 'Strong currents');
      expect((await sites.getSiteById('s1'))!.description, 'Strong currents');
      expect(
        (await sites.getSiteById('s2'))!.description,
        'Reef\n\nStrong currents',
      );
      final pending = await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'diveSites' AND record_id IN ('s1', 's2')",
      );
      expect(pending, 2);
    },
  );
}
