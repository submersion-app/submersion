import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/data/services/bulk_tag_service.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

/// Bulk tag edits on media items with undo (issue #1970).
void main() {
  late TagLinkRepository links;
  late BulkTagService service;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('m1', '', 'photo', 1, 1), ('m2', '', 'photo', 1, 1), "
      "('m3', '', 'photo', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, applies_to_media) '
      "VALUES ('wreck', 'Wreck', 0, 0, 1), ('fish', 'Fish', 0, 0, 1), "
      "('funny', 'Funny', 0, 0, 1)",
    );
    links = TagLinkRepository(TagScope.media);
    service = BulkTagService(links, itemTable: 'media');
  });
  tearDown(tearDownTestDatabase);

  Future<Map<String, Set<String>>> sets() async => {
    for (final e in (await links.getTagIdsByItem(['m1', 'm2', 'm3'])).entries)
      e.key: e.value.toSet(),
  };

  test('apply and undo restore the exact prior sets', () async {
    await links.replaceTags('m1', ['wreck']);
    await links.replaceTags('m2', ['wreck', 'fish']);

    final prior = await service.apply(
      itemIds: ['m1', 'm2', 'm3'],
      addTagIds: {'funny'},
      removeTagIds: {'wreck'},
    );
    expect(await sets(), {
      'm1': {'funny'},
      'm2': {'fish', 'funny'},
      'm3': {'funny'},
    });
    expect(prior, {
      'm1': ['wreck'],
      'm2': ['wreck', 'fish'],
      'm3': <String>[],
    });

    await service.undo(prior);
    expect(await sets(), {
      'm1': {'wreck'},
      'm2': {'wreck', 'fish'},
    });
  });

  test('neither apply nor undo writes a media row', () async {
    final prior = await service.apply(
      itemIds: ['m1'],
      addTagIds: {'wreck'},
      removeTagIds: const {},
    );
    await service.undo(prior);

    final db = DatabaseService.instance.database;
    final bumped = await db
        .customSelect('SELECT id FROM media WHERE updated_at <> 1')
        .get();
    final marked = await db
        .customSelect(
          "SELECT record_id FROM sync_records WHERE entity_type = 'media'",
        )
        .get();
    expect(bumped, isEmpty);
    expect(marked, isEmpty);
  });

  test('undo skips an item and a tag deleted since apply', () async {
    await links.replaceTags('m1', ['wreck', 'fish']);
    await links.replaceTags('m2', ['wreck']);
    final prior = await service.apply(
      itemIds: ['m1', 'm2'],
      addTagIds: const {},
      removeTagIds: {'wreck', 'fish'},
    );

    final db = DatabaseService.instance.database;
    await db.customStatement("DELETE FROM media WHERE id = 'm2'");
    await db.customStatement("DELETE FROM tags WHERE id = 'fish'");
    await service.undo(prior);

    expect(await sets(), {
      'm1': {'wreck'},
    });
  });

  test('an empty change writes nothing', () async {
    expect(
      await service.apply(
        itemIds: ['m1'],
        addTagIds: const {},
        removeTagIds: const {},
      ),
      isEmpty,
    );
    expect(await sets(), isEmpty);
  });
}
