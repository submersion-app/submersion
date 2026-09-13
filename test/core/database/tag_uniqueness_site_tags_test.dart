import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

void main() {
  test(
    'collapsing duplicate tags repoints site_tags and ORs the scopes',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // A database that lost the tag index (a restore of an old file).
      await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Site', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites) "
        "VALUES ('a', 'To try', 0, 0, 1, 0), ('b', 'to try', 0, 0, 0, 1)",
      );
      await db.customStatement(
        "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
        "VALUES ('st1', 's1', 'b', 0)",
      );

      await collapseDuplicateTags(db);

      final tags = await db
          .customSelect(
            'SELECT id, applies_to_dives, applies_to_sites FROM tags',
          )
          .get();
      expect(tags, hasLength(1));
      expect(tags.single.read<String>('id'), 'a');
      expect(tags.single.read<int>('applies_to_dives'), 1);
      expect(tags.single.read<int>('applies_to_sites'), 1);

      final links = await db.customSelect('SELECT tag_id FROM site_tags').get();
      expect(links.map((r) => r.read<String>('tag_id')).toList(), ['a']);
    },
  );

  test('a site holding both a loser and its survivor keeps one link', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('a', 'Avoid', 0, 0), ('b', 'avoid', 0, 0)",
    );
    // The site_tags unique index is present, so the repoint must not
    // abort on the (s1, a) pair that already exists.
    await db.customStatement(
      "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
      "VALUES ('x', 's1', 'a', 0), ('y', 's1', 'b', 0)",
    );

    await collapseDuplicateTags(db);

    final links = await db
        .customSelect('SELECT id, tag_id FROM site_tags')
        .get();
    expect(links, hasLength(1));
    expect(links.single.read<String>('tag_id'), 'a');
  });
}
