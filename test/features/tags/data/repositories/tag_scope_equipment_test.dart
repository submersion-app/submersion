import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show EquipmentTagsCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

/// The equipment tag scope through TagRepository (issue #1942). The
/// repository has been registry-driven since the scope refactor; these pin
/// that the third registry entry reaches every scope path.
void main() {
  late TagRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> linkItem(String equipmentId, String tagId) =>
      DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('et-$equipmentId-$tagId', '$equipmentId', '$tagId', 0)",
      );

  Future<int> count(String sql) async {
    final row = await DatabaseService.instance.database
        .customSelect(sql)
        .getSingle();
    return row.read<int>('n');
  }

  Future<void> expectItemsUntouched() async {
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = 'equipment'",
      ),
      0,
      reason: 'a link change never marks the item pending (#1769)',
    );
    expect(
      await count('SELECT COUNT(*) AS n FROM equipment WHERE updated_at <> 1'),
      0,
      reason: 'a link change never bumps the item',
    );
  }

  test(
    'a tag created from the equipment picker applies to equipment only',
    () async {
      final tag = await repository.getOrCreateTag(
        'Rental',
        scope: TagScope.equipment,
      );
      expect(tag.scopes, {TagScope.equipment});
      final stored = await repository.getTagById(tag.id);
      expect(stored!.scopes, {TagScope.equipment});
    },
  );

  test('a name collision widens the existing tag to equipment', () async {
    final diveTag = await repository.getOrCreateTag('Night');
    final widened = await repository.getOrCreateTag(
      'night',
      scope: TagScope.equipment,
    );

    expect(widened.id, diveTag.id);
    expect(widened.scopes, {TagScope.dives, TagScope.equipment});
    final stored = await repository.getTagById(diveTag.id);
    expect(stored!.appliesTo(TagScope.equipment), isTrue);
  });

  test(
    'createTag on a colliding name widens the incumbent to equipment',
    () async {
      final diveTag = await repository.getOrCreateTag('Night');
      final result = await repository.createTag(
        Tag.create(id: '', name: 'NIGHT', scope: TagScope.equipment),
      );
      expect(result.id, diveTag.id);
      expect(result.appliesTo(TagScope.equipment), isTrue);
    },
  );

  test('scope-filtered listing includes equipment', () async {
    await repository.getOrCreateTag('Night');
    await repository.getOrCreateTag('To try', scope: TagScope.sites);
    await repository.getOrCreateTag('Rental', scope: TagScope.equipment);

    final gear = await repository.getAllTags(scope: TagScope.equipment);
    final dives = await repository.getAllTags(scope: TagScope.dives);
    expect(gear.map((t) => t.name), ['Rental']);
    expect(dives.map((t) => t.name), ['Night']);
    expect(await repository.getAllTags(), hasLength(3));
  });

  test('turning off equipment removes and tombstones the links', () async {
    await repository.getOrCreateTag('Rental', scope: TagScope.equipment);
    final tag = await repository.getOrCreateTag('Rental');
    expect(tag.scopes, {TagScope.dives, TagScope.equipment});
    await linkItem('e1', tag.id);
    await linkItem('e2', tag.id);

    await repository.updateTag(tag.copyWith(scopes: {TagScope.dives}));

    final db = DatabaseService.instance.database;
    expect(await db.select(db.equipmentTags).get(), isEmpty);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      2,
    );
    expect((await repository.getTagById(tag.id))!.scopes, {TagScope.dives});
    await expectItemsUntouched();
  });

  test('a plain rename keeps the equipment links', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    await linkItem('e1', tag.id);

    await repository.updateTag(tag.copyWith(name: 'Rented'));

    final db = DatabaseService.instance.database;
    expect(await db.select(db.equipmentTags).get(), hasLength(1));
  });

  test('usage and statistics count equipment separately', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    await linkItem('e1', tag.id);
    await linkItem('e2', tag.id);

    expect(await repository.getTagUsage(tag.id), {
      TagScope.dives: 0,
      TagScope.sites: 0,
      TagScope.equipment: 2,
    });

    final stat = (await repository.getTagStatistics()).singleWhere(
      (s) => s.tag.id == tag.id,
    );
    expect(stat.count(TagScope.equipment), 2);
    expect(stat.count(TagScope.dives), 0);
  });

  test('statistics break dive and site ties by equipment use', () async {
    final alpha = await repository.getOrCreateTag(
      'Alpha',
      scope: TagScope.equipment,
    );
    final zulu = await repository.getOrCreateTag(
      'Zulu',
      scope: TagScope.equipment,
    );
    await linkItem('e1', alpha.id);
    await linkItem('e1', zulu.id);
    await linkItem('e2', zulu.id);

    final names = (await repository.getTagStatistics())
        .map((s) => s.tag.name)
        .toList();
    expect(names, ['Zulu', 'Alpha']);
  });

  test('merged usage counts an item carrying two of the tags once', () async {
    final a = await repository.getOrCreateTag('A', scope: TagScope.equipment);
    final b = await repository.getOrCreateTag('B', scope: TagScope.equipment);
    await linkItem('e1', a.id);
    await linkItem('e1', b.id);
    await linkItem('e2', b.id);

    expect(await repository.getMergedUsage([a.id, b.id]), {
      TagScope.dives: 0,
      TagScope.sites: 0,
      TagScope.equipment: 2,
    });
  });

  test('merging unions the scopes and relinks equipment tags', () async {
    final survivor = await repository.getOrCreateTag('Night');
    final rental = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    final travel = await repository.getOrCreateTag(
      'Travel kit',
      scope: TagScope.equipment,
    );
    await linkItem('e1', rental.id);
    await linkItem('e2', rental.id);
    // e2 carries both sources, so it must end with one survivor link.
    await linkItem('e2', travel.id);

    await repository.mergeTags(
      sourceTagIds: [rental.id, travel.id],
      survivingTagId: survivor.id,
      name: 'Night',
      colorHex: null,
    );

    final merged = await repository.getTagById(survivor.id);
    expect(merged!.scopes, {TagScope.dives, TagScope.equipment});
    expect(await repository.getTagById(rental.id), isNull);
    expect(await repository.getTagById(travel.id), isNull);
    final db = DatabaseService.instance.database;
    final links = await db.select(db.equipmentTags).get();
    expect(links, hasLength(2));
    expect(links.map((l) => (l.equipmentId, l.tagId)).toSet(), {
      ('e1', survivor.id),
      ('e2', survivor.id),
    });
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      3,
      reason: 'every source link is tombstoned',
    );
    await expectItemsUntouched();
  });

  test('deleting a tag takes its equipment links with it', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    await linkItem('e1', tag.id);

    await repository.deleteTag(tag.id);

    final db = DatabaseService.instance.database;
    expect(await db.select(db.equipmentTags).get(), isEmpty);
  });

  test('an equipment link change emits the tag link tick', () async {
    final tag = await repository.getOrCreateTag(
      'Rental',
      scope: TagScope.equipment,
    );
    final emitted = <void>[];
    final sub = repository.watchTagLinkChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    // A typed insert: Drift cannot tell which table a raw statement touched.
    final db = DatabaseService.instance.database;
    await db
        .into(db.equipmentTags)
        .insert(
          EquipmentTagsCompanion.insert(
            id: 'et1',
            equipmentId: 'e1',
            tagId: tag.id,
            createdAt: 0,
          ),
        );
    await pumpEventQueue();

    expect(emitted, isNotEmpty);
  });
}
