import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

/// A scope's tag links through TagLinkRepository (issue #1970): the media
/// and document junctions, written as clockless children of their item.
void main() {
  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('i1', '', 'photo', 1, 1), ('i2', '', 'photo', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO documents (id, diver_id, type, created_at, updated_at) '
      "VALUES ('i1', 'd1', 'other', 1, 1), ('i2', 'd1', 'other', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      'applies_to_media, applies_to_documents) VALUES '
      "('wreck', 'd1', 'Wreck', 0, 0, 1, 1), "
      "('fish', 'd1', 'fish', 0, 0, 1, 1), "
      "('club', 'd1', 'Club', 0, 0, 1, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<int> count(String sql) async {
    final row = await DatabaseService.instance.database
        .customSelect(sql)
        .getSingle();
    return row.read<int>('n');
  }

  for (final scope in const [TagScope.media, TagScope.documents]) {
    final entity = scope.table.syncEntity;
    final junction = scope.table.junctionTable;
    final parentTable = scope == TagScope.media ? 'media' : 'documents';

    Future<int> pending() => count(
      "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = '$entity'",
    );
    Future<int> tombstones() => count(
      "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = '$entity'",
    );

    Future<void> expectItemsUntouched() async {
      expect(
        await count(
          'SELECT COUNT(*) AS n FROM sync_records '
          "WHERE entity_type = '$parentTable'",
        ),
        0,
        reason: 'a link change never marks the item pending (#1769)',
      );
      expect(
        await count(
          'SELECT COUNT(*) AS n FROM $parentTable WHERE updated_at <> 1',
        ),
        0,
        reason: 'a link change never bumps the item',
      );
    }

    group(scope.name, () {
      late TagLinkRepository repository;
      setUp(() => repository = TagLinkRepository(scope));

      test('replaceTags sets the exact set, by name on read', () async {
        await repository.replaceTags('i1', ['wreck', 'fish']);
        expect((await repository.getTagsFor('i1')).map((t) => t.id), [
          'fish',
          'wreck',
        ]);
        expect(await pending(), 2);

        await repository.replaceTags('i1', ['wreck', 'club']);
        expect((await repository.getTagsFor('i1')).map((t) => t.name), [
          'Club',
          'Wreck',
        ]);
        expect(await tombstones(), 1, reason: 'fish was removed');
        expect(await pending(), 3, reason: 'only the new club link is added');
        await expectItemsUntouched();
      });

      test('a kept pair keeps its row', () async {
        await repository.replaceTags('i1', ['wreck']);
        final before = await DatabaseService.instance.database
            .customSelect('SELECT id FROM $junction')
            .getSingle();
        await repository.replaceTags('i1', ['wreck', 'fish']);
        final ids = await DatabaseService.instance.database
            .customSelect('SELECT id FROM $junction')
            .map((r) => r.read<String>('id'))
            .get();
        expect(ids, contains(before.read<String>('id')));
      });

      test('addTags skips pairs that exist and never removes', () async {
        await repository.replaceTags('i1', ['wreck']);
        await repository.addTags(['i1', 'i2'], ['wreck', 'fish']);

        final byItem = await repository.getTagIdsByItem(['i1', 'i2']);
        expect(byItem['i1'], ['wreck', 'fish']);
        expect(byItem['i2']!.toSet(), {'wreck', 'fish'});
        expect(await repository.tagCountsFor(['i1', 'i2']), {
          'wreck': 2,
          'fish': 2,
        });
        await expectItemsUntouched();
      });

      test('removeTags removes and tombstones only listed pairs', () async {
        await repository.addTags(['i1', 'i2'], ['wreck', 'fish']);
        await repository.removeTags(['i1'], ['wreck', 'club']);

        expect((await repository.getTagIdsByItem(['i1']))['i1'], ['fish']);
        expect((await repository.getTagIdsByItem(['i2']))['i2'], hasLength(2));
        expect(await tombstones(), 1);
      });

      test('getTagsByItem maps every tagged item in one read', () async {
        await repository.replaceTags('i1', ['wreck', 'fish']);
        await repository.replaceTags('i2', ['club']);

        final byItem = await repository.getTagsByItem();
        expect(byItem['i1']!.map((t) => t.name), ['fish', 'Wreck']);
        expect(byItem['i2']!.map((t) => t.name), ['Club']);
      });

      test('deleteLinksFor removes and tombstones an item\'s links', () async {
        await repository.replaceTags('i1', ['wreck', 'fish']);
        await repository.replaceTags('i2', ['club']);

        await repository.deleteLinksFor(['i1']);

        expect(await repository.getTagIdsByItem(['i1']), isEmpty);
        expect(await repository.getTagIdsByItem(['i2']), hasLength(1));
        expect(await tombstones(), 2);
      });

      test('a link change emits a change', () async {
        final emitted = <void>[];
        final sub = repository.watchChanges().listen(emitted.add);
        addTearDown(sub.cancel);

        await repository.addTags(['i1'], ['wreck']);
        await pumpEventQueue();

        expect(emitted, isNotEmpty);
      });
    });
  }
}
