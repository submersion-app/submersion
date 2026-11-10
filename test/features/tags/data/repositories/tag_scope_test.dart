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

  /// A tag offered in [scopes] only, as one narrowed in Manage Tags is.
  Future<Tag> narrow(String name, Set<TagScope> scopes) =>
      repository.createTag(Tag.create(id: '', name: name, scopes: scopes));

  Future<void> linkSite(String siteId, String tagId) =>
      DatabaseService.instance.database.customStatement(
        "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
        "VALUES ('st-$siteId-$tagId', '$siteId', '$tagId', 0)",
      );

  test(
    'site tag changes emit on the link watcher, so the site counts refresh',
    () async {
      final tag = await narrow('To try', {TagScope.sites});
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

  test(
    'a tag created from the site picker applies everywhere (#4407)',
    () async {
      final tag = await repository.getOrCreateTag(
        'To try',
        scope: TagScope.sites,
      );
      expect(tag.scopes, TagScope.everywhere);
      final stored = await repository.getTagById(tag.id);
      expect(stored!.scopes, TagScope.everywhere);
    },
  );

  test('a tag created by name applies everywhere (#4407)', () async {
    // Whichever scope asked for it, so it can be reused on any kind of item.
    for (final (name, scope) in const [
      ('Night', TagScope.dives),
      ('Wreck', TagScope.media),
    ]) {
      final tag = await repository.getOrCreateTag(name, scope: scope);
      expect(tag.scopes, TagScope.everywhere, reason: name);
      final stored = await repository.getTagById(tag.id);
      expect(stored!.scopes, TagScope.everywhere, reason: name);
    }
  });

  test('a name collision widens the existing tag instead of failing', () async {
    final diveTag = await narrow('Night', {TagScope.dives});
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

  test('an existing narrowed tag is widened to the scope only', () async {
    // A tag someone narrowed on purpose stays narrow: reusing it from
    // another scope adds that one scope, not every scope (#4407).
    final diveTag = await narrow('Night', {TagScope.dives});
    final reused = await repository.getOrCreateTag(
      'Night',
      scope: TagScope.sites,
    );
    expect(reused.id, diveTag.id);
    expect(reused.scopes, {TagScope.dives, TagScope.sites});
  });

  test(
    'createTag widens a colliding incumbent only to widenExistingTo',
    () async {
      final diveTag = await narrow('Night', {TagScope.dives});

      // Untouched "everywhere" defaults leave the incumbent as it was (#4407).
      final kept = await repository.createTag(
        Tag.create(id: '', name: 'night', scopes: TagScope.everywhere),
        widenExistingTo: const {},
      );
      expect(kept.id, diveTag.id);
      expect(kept.scopes, {TagScope.dives});

      final widened = await repository.createTag(
        Tag.create(id: '', name: 'NIGHT', scopes: TagScope.everywhere),
        widenExistingTo: const {TagScope.media},
      );
      expect(widened.id, diveTag.id);
      expect(widened.scopes, {TagScope.dives, TagScope.media});
    },
  );

  test('createTag on a colliding name widens the incumbent as asked', () async {
    final diveTag = await narrow('Night', {TagScope.dives});
    final result = await repository.createTag(
      Tag.create(id: '', name: 'NIGHT', scopes: {TagScope.sites}),
      widenExistingTo: const {TagScope.sites},
    );
    expect(result.id, diveTag.id);
    expect(result.appliesTo(TagScope.sites), isTrue);
  });

  test('createTag widens a colliding incumbent nothing by default', () async {
    // A new tag defaults to every scope, so widening by default would undo
    // a narrowing by accident (#4407).
    final diveTag = await narrow('Night', {TagScope.dives});
    final result = await repository.createTag(
      Tag.create(id: '', name: 'night'),
    );
    expect(result.id, diveTag.id);
    expect(result.scopes, {TagScope.dives});
    expect((await repository.getTagById(diveTag.id))!.scopes, {TagScope.dives});
  });

  test('scope-filtered listing', () async {
    await narrow('Night', {TagScope.dives});
    await narrow('To try', {TagScope.sites});

    final siteTags = await repository.getAllTags(scope: TagScope.sites);
    final diveTags = await repository.getAllTags(scope: TagScope.dives);
    final all = await repository.getAllTags();
    expect(siteTags.map((t) => t.name), ['To try']);
    expect(diveTags.map((t) => t.name), ['Night']);
    expect(all, hasLength(2));
  });

  test('a tag must apply to at least one of dives and sites', () async {
    final tag = await narrow('Night', {TagScope.dives});
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
    final tag = await narrow('To try', {TagScope.sites});
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
    final tag = await narrow('To try', {TagScope.sites});
    await linkSite('s1', tag.id);

    await repository.updateTag(tag.copyWith(name: 'To try soon'));

    final db = DatabaseService.instance.database;
    expect(await db.select(db.siteTags).get(), hasLength(1));
    expect((await repository.getTagById(tag.id))!.name, 'To try soon');
  });

  test('usage and statistics count dives and sites separately', () async {
    final tag = await narrow('To try', {TagScope.sites});
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
    final survivor = await narrow('Night', {TagScope.dives});
    final source = await narrow('Avoid', {TagScope.sites});
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
