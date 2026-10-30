import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

/// The media and document tag scopes through TagRepository (issue #1970).
/// The repository is registry-driven; these pin that both new registry
/// entries reach every scope path, against their real junction tables.
void main() {
  late TagRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('p1', '', 'photo', 1, 1), ('p2', '', 'photo', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO documents (id, diver_id, type, created_at, updated_at) '
      "VALUES ('p1', 'd1', 'other', 1, 1), ('p2', 'd1', 'other', 1, 1)",
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
    final junction = scope.table.junctionTable;
    final parentColumn = scope.table.parentColumn;
    final parentTable = scope == TagScope.media ? 'media' : 'documents';

    Future<void> link(String itemId, String tagId) =>
        DatabaseService.instance.database.customStatement(
          'INSERT INTO $junction (id, $parentColumn, tag_id, created_at) '
          "VALUES ('l-$itemId-$tagId', '$itemId', '$tagId', 0)",
        );

    Future<Set<(String, String)>> links() async {
      final rows = await DatabaseService.instance.database
          .customSelect('SELECT $parentColumn AS item, tag_id FROM $junction')
          .get();
      return {
        for (final r in rows)
          (r.read<String>('item'), r.read<String>('tag_id')),
      };
    }

    Future<void> expectItemsUntouched() async {
      expect(
        await count(
          'SELECT COUNT(*) AS n FROM $parentTable WHERE updated_at <> 1',
        ),
        0,
        reason: 'a link change never bumps the item (#1769)',
      );
    }

    group(scope.name, () {
      test('a tag created in the scope applies there only', () async {
        final tag = await repository.getOrCreateTag('Wreck', scope: scope);
        expect(tag.scopes, {scope});
        expect((await repository.getTagById(tag.id))!.scopes, {scope});
        expect((await repository.getAllTags(scope: scope)).map((t) => t.name), [
          'Wreck',
        ]);
        expect(await repository.getAllTags(scope: TagScope.dives), isEmpty);
      });

      test('a name collision widens the existing tag', () async {
        final diveTag = await repository.getOrCreateTag('Night');
        final widened = await repository.getOrCreateTag('NIGHT', scope: scope);
        expect(widened.id, diveTag.id);
        expect(widened.scopes, {TagScope.dives, scope});
      });

      test('usage counts the scope separately', () async {
        final tag = await repository.getOrCreateTag('Wreck', scope: scope);
        await link('p1', tag.id);
        await link('p2', tag.id);

        final usage = await repository.getTagUsage(tag.id);
        expect(usage[scope], 2);
        expect(usage[TagScope.dives], 0);
        final stat = (await repository.getTagStatistics()).singleWhere(
          (s) => s.tag.id == tag.id,
        );
        expect(stat.count(scope), 2);
      });

      test('turning the scope off removes and tombstones the links', () async {
        await repository.getOrCreateTag('Wreck', scope: scope);
        final tag = await repository.getOrCreateTag('Wreck');
        await link('p1', tag.id);
        await link('p2', tag.id);

        await repository.updateTag(tag.copyWith(scopes: {TagScope.dives}));

        expect(await links(), isEmpty);
        expect(
          await count(
            'SELECT COUNT(*) AS n FROM deletion_log '
            "WHERE entity_type = '${scope.table.syncEntity}'",
          ),
          2,
        );
        await expectItemsUntouched();
      });

      test('merging unions the scopes and relinks', () async {
        final survivor = await repository.getOrCreateTag('Night');
        final a = await repository.getOrCreateTag('A', scope: scope);
        final b = await repository.getOrCreateTag('B', scope: scope);
        await link('p1', a.id);
        await link('p2', a.id);
        await link('p2', b.id);

        expect((await repository.getMergedUsage([a.id, b.id]))[scope], 2);

        await repository.mergeTags(
          sourceTagIds: [a.id, b.id],
          survivingTagId: survivor.id,
          name: 'Night',
          colorHex: null,
        );

        expect((await repository.getTagById(survivor.id))!.scopes, {
          TagScope.dives,
          scope,
        });
        expect(await links(), {('p1', survivor.id), ('p2', survivor.id)});
        await expectItemsUntouched();
      });

      test('deleting a tag takes its links with it', () async {
        final tag = await repository.getOrCreateTag('Wreck', scope: scope);
        await link('p1', tag.id);

        await repository.deleteTag(tag.id);

        expect(await links(), isEmpty);
      });

      test('the duplicate-tag repair repoints links to the survivor', () async {
        final db = DatabaseService.instance.database;
        // Two spellings of one name, as a pre-index peer could leave them.
        await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
        await db.customStatement(
          'INSERT INTO tags (id, diver_id, name, created_at, updated_at) '
          "VALUES ('old', 'd1', 'Wreck', 1, 1), ('new', 'd1', 'wreck', 2, 2)",
        );
        await link('p1', 'new');

        await collapseDuplicateTags(db);

        final survivors = await db
            .customSelect('SELECT id FROM tags')
            .map((r) => r.read<String>('id'))
            .get();
        expect(survivors, hasLength(1));
        expect(await links(), {('p1', survivors.single)});
      });
    });
  }
}
