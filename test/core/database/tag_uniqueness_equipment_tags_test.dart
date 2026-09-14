import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

/// The duplicate-tag repair and the equipment_tags index (v219, issue #1942).
void main() {
  Future<AppDatabase> openWithItem() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 0, 0)",
    );
    return db;
  }

  test(
    'collapsing duplicate tags repoints equipment_tags and ORs the scopes',
    () async {
      final db = await openWithItem();
      // A database that lost the tag index (a restore of an old file).
      await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites, applies_to_equipment) "
        "VALUES ('a', 'Rental', 0, 0, 1, 0, 0), "
        "('b', 'rental', 0, 0, 0, 0, 1)",
      );
      await db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('et1', 'e1', 'b', 0)",
      );

      await collapseDuplicateTags(db);

      final tags = await db
          .customSelect(
            'SELECT id, applies_to_dives, applies_to_equipment FROM tags',
          )
          .get();
      expect(tags, hasLength(1));
      expect(tags.single.read<String>('id'), 'a');
      expect(tags.single.read<int>('applies_to_dives'), 1);
      expect(tags.single.read<int>('applies_to_equipment'), 1);

      final links = await db
          .customSelect('SELECT tag_id FROM equipment_tags')
          .get();
      expect(links.map((r) => r.read<String>('tag_id')).toList(), ['a']);
    },
  );

  test(
    'an item holding both a loser and its survivor keeps one link',
    () async {
      final db = await openWithItem();
      await db.customStatement('DROP INDEX IF EXISTS $kTagsUniqueIndexName');
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at) "
        "VALUES ('a', 'Rental', 0, 0), ('b', 'rental', 0, 0)",
      );
      // The equipment_tags unique index is present, so the repoint must not
      // abort on the (e1, a) pair that already exists.
      await db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('x', 'e1', 'a', 0), ('y', 'e1', 'b', 0)",
      );

      await collapseDuplicateTags(db);

      final links = await db
          .customSelect('SELECT id, tag_id FROM equipment_tags')
          .get();
      expect(links, hasLength(1));
      expect(links.single.read<String>('tag_id'), 'a');
    },
  );

  test(
    'a lost junction index is rebuilt after its duplicates collapse',
    () async {
      final db = await openWithItem();
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at) "
        "VALUES ('t1', 'Rental', 0, 0)",
      );
      await db.customStatement('DROP INDEX $kEquipmentTagsUniqueIndexName');
      await db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('y', 'e1', 't1', 1), ('x', 'e1', 't1', 0)",
      );

      await assertEquipmentTagUniqueness(db);

      final links = await db
          .customSelect('SELECT id FROM equipment_tags')
          .get();
      expect(links.map((r) => r.read<String>('id')).toList(), ['x']);
      final index = await db
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?",
            variables: const [Variable<String>(kEquipmentTagsUniqueIndexName)],
          )
          .get();
      expect(index, isNotEmpty);
    },
  );
}
