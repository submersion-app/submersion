import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

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

  test('a tag created from the site picker applies to sites only', () async {
    final tag = await repository.getOrCreateTag(
      'To try',
      scope: TagScope.sites,
    );
    expect(tag.appliesToSites, isTrue);
    expect(tag.appliesToDives, isFalse);
    final stored = await repository.getTagById(tag.id);
    expect(stored!.appliesToSites, isTrue);
    expect(stored.appliesToDives, isFalse);
  });

  test('a tag created without a scope stays a dive tag', () async {
    final tag = await repository.getOrCreateTag('Night');
    expect(tag.appliesToDives, isTrue);
    expect(tag.appliesToSites, isFalse);
  });

  test('a name collision widens the existing tag instead of failing', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final widened = await repository.getOrCreateTag(
      'night',
      scope: TagScope.sites,
    );

    expect(widened.id, diveTag.id);
    expect(widened.appliesToDives, isTrue);
    expect(widened.appliesToSites, isTrue);
    final stored = await repository.getTagById(diveTag.id);
    expect(stored!.appliesToSites, isTrue);
  });

  test('createTag on a colliding name widens the incumbent too', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final result = await repository.createTag(
      Tag.create(id: '', name: 'NIGHT', scope: TagScope.sites),
    );
    expect(result.id, diveTag.id);
    expect(result.appliesToSites, isTrue);
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
      repository.updateTag(
        tag.copyWith(appliesToDives: false, appliesToSites: false),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.createTag(
        Tag.create(id: '', name: 'Nothing').copyWith(appliesToDives: false),
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

    await repository.updateTag(
      tag.copyWith(appliesToDives: true, appliesToSites: false),
    );

    final db = DatabaseService.instance.database;
    expect(await db.select(db.siteTags).get(), isEmpty);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'siteTags'",
        )
        .get();
    expect(tombstones, hasLength(1));
    final stored = await repository.getTagById(tag.id);
    expect(stored!.appliesToDives, isTrue);
    expect(stored.appliesToSites, isFalse);
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

    expect(await repository.getTagUsage(tag.id), (dives: 0, sites: 1));
    final stats = await repository.getTagStatistics();
    final stat = stats.singleWhere((s) => s.tag.id == tag.id);
    expect(stat.siteCount, 1);
    expect(stat.diveCount, 0);
    expect(stat.tag.appliesToSites, isTrue);
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
    expect(merged!.appliesToDives, isTrue);
    expect(merged.appliesToSites, isTrue);
    expect(await repository.getTagById(source.id), isNull);
    final db = DatabaseService.instance.database;
    final links = await db.select(db.siteTags).get();
    expect(links.single.tagId, survivor.id);
  });
}
