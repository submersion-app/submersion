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

  test('appendDescription adds a newline only after existing text', () async {
    final sites = SiteRepository();
    await sites.appendDescription('s1', 'Strong currents');
    await sites.appendDescription('s2', 'Strong currents');
    expect((await sites.getSiteById('s1'))!.description, 'Strong currents');
    expect(
      (await sites.getSiteById('s2'))!.description,
      'Reef\nStrong currents',
    );
    final pending = await count(
      "SELECT COUNT(*) AS n FROM sync_records "
      "WHERE entity_type = 'diveSites' AND record_id IN ('s1', 's2')",
    );
    expect(pending, 2);
  });
}
