import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show DiveTagsCompanion, SiteTagsCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';
import '../../tag_test_helpers.dart';

/// The tag scope registry drives every multi-scope path of TagRepository
/// (issue #1942). Same results as the per-scope code it replaced.
void main() {
  late TagRepository repository;

  Future<void> exec(String sql) =>
      DatabaseService.instance.database.customStatement(sql);

  Future<List<String>> rows(String sql) async => [
    for (final row
        in await DatabaseService.instance.database.customSelect(sql).get())
      row.data.values.join('|'),
  ];

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
    await exec(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0), ('d2', 0, 0, 0)",
    );
    await exec(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'One', 0, 0), ('s2', 'Two', 0, 0)",
    );
    // Zulu: dives only. Bravo: sites only. Both: dives and sites.
    // Alpha: a dive tag nothing carries.
    await exec(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites) VALUES '
      "('zulu', 'Zulu', 0, 0, 1, 0), ('bravo', 'Bravo', 0, 0, 0, 1), "
      "('both', 'Both', 0, 0, 1, 1), ('idle', 'Alpha', 0, 0, 1, 0)",
    );
    await exec(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) VALUES '
      "('dz1', 'd1', 'zulu', 0), ('dz2', 'd2', 'zulu', 0), "
      "('db1', 'd1', 'both', 0)",
    );
    await exec(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at) VALUES '
      "('sb1', 's1', 'bravo', 0), ('sx1', 's1', 'both', 0), "
      "('sx2', 's2', 'both', 0)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  test('usage counts each scope separately', () async {
    expect(divesAndSites(await repository.getTagUsage('both')), (
      dives: 1,
      sites: 2,
    ));
    expect(divesAndSites(await repository.getTagUsage('idle')), (
      dives: 0,
      sites: 0,
    ));
  });

  test('usage maps carry every registry scope', () async {
    expect((await repository.getTagUsage('zulu')).keys, TagScope.values);
    expect((await repository.getMergedUsage(['zulu'])).keys, TagScope.values);
    expect((await repository.getMergedUsage([])).keys, TagScope.values);
  });

  test('merged usage counts an item carrying two of the tags once', () async {
    // d1 carries zulu and both; s1 carries bravo and both.
    final usage = await repository.getMergedUsage(['zulu', 'bravo', 'both']);
    expect(divesAndSites(usage), (dives: 2, sites: 2));
  });

  test('statistics order by dives, then sites, then name', () async {
    final stats = await repository.getTagStatistics();
    expect(stats.map((s) => s.tag.name), ['Zulu', 'Both', 'Bravo', 'Alpha']);
    final both = stats.singleWhere((s) => s.tag.id == 'both');
    expect(both.count(TagScope.dives), 1);
    expect(both.count(TagScope.sites), 2);
    expect(both.tag.scopes, {TagScope.dives, TagScope.sites});
  });

  test('a merge relinks every junction, unions the scopes and re-stamps '
      'only dives', () async {
    await repository.mergeTags(
      sourceTagIds: ['bravo', 'both'],
      survivingTagId: 'zulu',
      name: 'Zulu',
      colorHex: null,
    );

    expect(
      await rows('SELECT dive_id, tag_id FROM dive_tags ORDER BY dive_id'),
      ['d1|zulu', 'd2|zulu'],
    );
    expect(
      await rows('SELECT site_id, tag_id FROM site_tags ORDER BY site_id'),
      ['s1|zulu', 's2|zulu'],
    );
    expect((await repository.getTagById('zulu'))!.scopes, {
      TagScope.dives,
      TagScope.sites,
    });
    // Every source link is tombstoned, moved or dropped as covered.
    expect(
      await rows(
        'SELECT entity_type, record_id FROM deletion_log '
        "WHERE entity_type IN ('diveTags', 'siteTags') "
        'ORDER BY entity_type, record_id',
      ),
      ['diveTags|db1', 'siteTags|sb1', 'siteTags|sx1', 'siteTags|sx2'],
    );
    // A dive link re-stamps its dive; a site link is a clockless child.
    expect(
      await rows(
        "SELECT record_id FROM sync_records WHERE entity_type = 'dives'",
      ),
      ['d1'],
    );
    expect(
      await rows(
        "SELECT record_id FROM sync_records WHERE entity_type = 'diveSites'",
      ),
      isEmpty,
    );
    expect(await rows("SELECT updated_at FROM dives WHERE id = 'd2'"), ['0']);
  });

  test(
    'narrowing removes and tombstones links and re-stamps no parent',
    () async {
      final tag = (await repository.getTagById('both'))!;
      await repository.updateTag(tag.copyWith(scopes: const {TagScope.sites}));

      expect(
        await rows("SELECT id FROM dive_tags WHERE tag_id = 'both'"),
        isEmpty,
      );
      expect(
        await rows(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'diveTags'",
        ),
        ['db1'],
      );
      expect(
        await rows(
          "SELECT record_id FROM sync_records WHERE entity_type = 'dives'",
        ),
        isEmpty,
        reason: 'narrowing never re-stamped the dives it unlinked',
      );
      expect(
        await rows(
          "SELECT site_id FROM site_tags WHERE tag_id = 'both' ORDER BY site_id",
        ),
        ['s1', 's2'],
      );
    },
  );

  test('narrowing notifies the link watchers', () async {
    // A tags UPDATE does not cascade to the junctions, so this only emits if
    // the unlink tells Drift which junction it wrote.
    final emitted = <void>[];
    final sub = repository.watchTagLinkChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    final tag = (await repository.getTagById('both'))!;
    await repository.updateTag(tag.copyWith(scopes: const {TagScope.dives}));
    await pumpEventQueue();

    expect(emitted, isNotEmpty);
  });

  test('link changes on every junction emit', () async {
    final db = DatabaseService.instance.database;
    final emitted = <void>[];
    final sub = repository.watchTagLinkChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    // Typed inserts: Drift cannot tell which table a raw statement touched.
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion.insert(
            id: 'new-dive-link',
            diveId: 'd2',
            tagId: 'both',
            createdAt: 0,
          ),
        );
    await pumpEventQueue();
    expect(emitted, isNotEmpty);

    emitted.clear();
    await db
        .into(db.siteTags)
        .insert(
          SiteTagsCompanion.insert(
            id: 'new-site-link',
            siteId: 's2',
            tagId: 'bravo',
            createdAt: 0,
          ),
        );
    await pumpEventQueue();
    expect(emitted, isNotEmpty);
  });
}
