import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';

import '../../../../helpers/test_database.dart';

/// The site type and site tag junctions (issue #1765).
void main() {
  late SiteClassificationRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteClassificationRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'A', 0, 0), ('s2', 'B', 0, 0)",
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

  test('replaceTypes keeps the chosen order and reads it back', () async {
    await repository.replaceTypes('s1', ['wreck', 'lake']);
    final types = await repository.getTypesForSite('s1');
    expect(types.map((t) => t.id), ['wreck', 'lake']);
  });

  test(
    'replaceTypes removes only what left the set and tombstones it',
    () async {
      final db = DatabaseService.instance.database;
      await repository.replaceTypes('s1', ['wreck', 'lake']);
      final before = await db.select(db.siteSiteTypes).get();
      final wreckRowId = before.firstWhere((r) => r.siteTypeId == 'wreck').id;

      await repository.replaceTypes('s1', ['wreck', 'reef']);

      final after = await db.select(db.siteSiteTypes).get();
      expect(after.map((r) => r.siteTypeId).toSet(), {'wreck', 'reef'});
      expect(
        after.firstWhere((r) => r.siteTypeId == 'wreck').id,
        wreckRowId,
        reason: 'an unchanged pair keeps its row',
      );
      expect(
        await count(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'siteSiteTypes'",
        ),
        1,
      );
    },
  );

  test('addTypes unions and never removes', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.addTypes('s1', ['wreck', 'lake']);
    final types = await repository.getTypesForSite('s1');
    expect(types.map((t) => t.id), ['wreck', 'lake']);
  });

  test('replaceTags and addTags manage the tag set', () async {
    await repository.replaceTags('s1', ['t1', 't2']);
    await repository.replaceTags('s1', ['t2']);
    expect((await repository.getTagsForSite('s1')).map((t) => t.id), ['t2']);
    await repository.addTags('s1', ['t1', 't2']);
    expect((await repository.getTagsForSite('s1')).map((t) => t.name), [
      'Avoid',
      'To try',
    ]);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = 'siteTags'",
      ),
      1,
    );
  });

  test('junction writes mark the rows pending, never the parent site', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.replaceTags('s1', ['t1']);

    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'diveSites'",
      ),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'siteSiteTypes'",
      ),
      1,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = 'siteTags'",
      ),
      1,
    );
  });

  test('batch reads group by site', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.replaceTypes('s2', ['lake', 'reef']);
    await repository.replaceTags('s2', ['t2', 't1']);

    final types = await repository.getTypesBySite();
    final tags = await repository.getTagsBySite();
    expect(types['s1']!.map((t) => t.id), ['wreck']);
    expect(types['s2']!.map((t) => t.id), ['lake', 'reef']);
    expect(tags['s2']!.map((t) => t.name), ['Avoid', 'To try']);
    expect(tags.containsKey('s1'), isFalse);

    expect(await repository.getTypeIdsBySite(['s1', 's2']), {
      's1': ['wreck'],
      's2': ['lake', 'reef'],
    });
    expect((await repository.getTagIdsBySite(['s2']))['s2']!.toSet(), {
      't1',
      't2',
    });
  });

  test('a link to a custom type that has not synced yet is skipped', () async {
    await repository.replaceTypes('s1', ['not-arrived', 'reef']);
    final types = await repository.getTypesForSite('s1');
    expect(types.map((t) => t.id), ['reef']);
  });

  test('relinkForMerge moves links and drops duplicates', () async {
    await repository.replaceTypes('s1', ['wreck']);
    await repository.replaceTypes('s2', ['wreck', 'lake']);
    await repository.replaceTags('s2', ['t1']);

    await repository.relinkForMerge(['s2'], 's1');

    final types = await repository.getTypesForSite('s1');
    expect(types.map((t) => t.id).toSet(), {'wreck', 'lake'});
    expect(await repository.getTypesForSite('s2'), isEmpty);
    expect((await repository.getTagsForSite('s1')).single.id, 't1');
  });
}
