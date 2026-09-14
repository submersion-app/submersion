import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show SiteTagsCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';
import '../../tag_test_helpers.dart';

/// Tag scope: dives, sites, or both (issue #1765).
void main() {
  late TagRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> linkSite(String siteId, String tagId) =>
      DatabaseService.instance.database.customStatement(
        "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
        "VALUES ('st-$siteId-$tagId', '$siteId', '$tagId', 0)",
      );

  test(
    'site tag changes emit on the link watcher, so the site counts refresh',
    () async {
      final tag = await repository.getOrCreateTag(
        'To try',
        scope: TagScope.sites,
      );
      final emitted = <void>[];
      final sub = repository.watchTagLinkChanges().listen(emitted.add);
      addTearDown(sub.cancel);

      // A typed insert: Drift cannot tell which table a raw statement touched.
      final db = DatabaseService.instance.database;
      await db
          .into(db.siteTags)
          .insert(
            SiteTagsCompanion.insert(
              id: 'st1',
              siteId: 's1',
              tagId: tag.id,
              createdAt: 0,
            ),
          );
      await pumpEventQueue();

      expect(emitted, isNotEmpty);
    },
  );

  test('a tag created from the site picker applies to sites only', () async {
    final tag = await repository.getOrCreateTag(
      'To try',
      scope: TagScope.sites,
    );
    expect(tag.appliesTo(TagScope.sites), isTrue);
    expect(tag.appliesTo(TagScope.dives), isFalse);
    final stored = await repository.getTagById(tag.id);
    expect(stored!.appliesTo(TagScope.sites), isTrue);
    expect(stored.appliesTo(TagScope.dives), isFalse);
  });

  test('a tag created without a scope stays a dive tag', () async {
    final tag = await repository.getOrCreateTag('Night');
    expect(tag.appliesTo(TagScope.dives), isTrue);
    expect(tag.appliesTo(TagScope.sites), isFalse);
  });

  test('a name collision widens the existing tag instead of failing', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final widened = await repository.getOrCreateTag(
      'night',
      scope: TagScope.sites,
    );

    expect(widened.id, diveTag.id);
    expect(widened.appliesTo(TagScope.dives), isTrue);
    expect(widened.appliesTo(TagScope.sites), isTrue);
    final stored = await repository.getTagById(diveTag.id);
    expect(stored!.appliesTo(TagScope.sites), isTrue);
  });

  test('createTag on a colliding name widens the incumbent too', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final result = await repository.createTag(
      Tag.create(id: '', name: 'NIGHT', scope: TagScope.sites),
    );
    expect(result.id, diveTag.id);
    expect(result.appliesTo(TagScope.sites), isTrue);
  });

  test('scope-filtered listing', () async {
    await repository.getOrCreateTag('Night');
    await repository.getOrCreateTag('To try', scope: TagScope.sites);

    final siteTags = await repository.getAllTags(scope: TagScope.sites);
    final diveTags = await repository.getAllTags(scope: TagScope.dives);
    final all = await repository.getAllTags();
    expect(siteTags.map((t) => t.name), ['To try']);
    expect(diveTags.map((t) => t.name), ['Night']);
    expect(all, hasLength(2));
  });

  test('a tag must apply to at least one of dives and sites', () async {
    final tag = await repository.getOrCreateTag('Night');
    await expectLater(
      repository.updateTag(tag.copyWith(scopes: const {})),
      throwsArgumentError,
    );
    await expectLater(
      repository.createTag(
        Tag.create(id: '', name: 'Nothing').copyWith(scopes: const {}),
      ),
      throwsArgumentError,
    );
  });

  test('turning off sites removes and tombstones the site links', () async {
    final tag = await repository.getOrCreateTag(
      'To try',
      scope: TagScope.sites,
    );
    await linkSite('s1', tag.id);

    await repository.updateTag(tag.copyWith(scopes: const {TagScope.dives}));

    final db = DatabaseService.instance.database;
    expect(await db.select(db.siteTags).get(), isEmpty);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'siteTags'",
        )
        .get();
    expect(tombstones, hasLength(1));
    final stored = await repository.getTagById(tag.id);
    expect(stored!.appliesTo(TagScope.dives), isTrue);
    expect(stored.appliesTo(TagScope.sites), isFalse);
  });

  test('a plain rename keeps the site links', () async {
    final tag = await repository.getOrCreateTag(
      'To try',
      scope: TagScope.sites,
    );
    await linkSite('s1', tag.id);

    await repository.updateTag(tag.copyWith(name: 'To try soon'));

    final db = DatabaseService.instance.database;
    expect(await db.select(db.siteTags).get(), hasLength(1));
    expect((await repository.getTagById(tag.id))!.name, 'To try soon');
  });

  test('usage and statistics count dives and sites separately', () async {
    final tag = await repository.getOrCreateTag(
      'To try',
      scope: TagScope.sites,
    );
    await linkSite('s1', tag.id);

    expect(divesAndSites(await repository.getTagUsage(tag.id)), (
      dives: 0,
      sites: 1,
    ));
    final stats = await repository.getTagStatistics();
    final stat = stats.singleWhere((s) => s.tag.id == tag.id);
    expect(stat.count(TagScope.sites), 1);
    expect(stat.count(TagScope.dives), 0);
    expect(stat.tag.appliesTo(TagScope.sites), isTrue);
  });

  test('merging ORs the scopes and relinks site tags', () async {
    final survivor = await repository.getOrCreateTag('Night');
    final source = await repository.getOrCreateTag(
      'Avoid',
      scope: TagScope.sites,
    );
    await linkSite('s1', source.id);

    await repository.mergeTags(
      sourceTagIds: [source.id],
      survivingTagId: survivor.id,
      name: 'Night',
      colorHex: null,
    );

    final merged = await repository.getTagById(survivor.id);
    expect(merged!.appliesTo(TagScope.dives), isTrue);
    expect(merged.appliesTo(TagScope.sites), isTrue);
    expect(await repository.getTagById(source.id), isNull);
    final db = DatabaseService.instance.database;
    final links = await db.select(db.siteTags).get();
    expect(links.single.tagId, survivor.id);
  });
}
