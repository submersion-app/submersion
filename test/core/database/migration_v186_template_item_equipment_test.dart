import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Pre-v186 pre_dive_checklist_template_items shape: no equipment link.
const _preV186TemplateItems = '''
  CREATE TABLE pre_dive_checklist_template_items (
    id TEXT NOT NULL PRIMARY KEY,
    template_id TEXT NOT NULL,
    title TEXT NOT NULL,
    item_type TEXT NOT NULL DEFAULT 'check',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';

void main() {
  test('v186 adds the equipment_id column, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 185');
        rawDb.execute(_preV186TemplateItems);
        rawDb.execute(
          "INSERT INTO pre_dive_checklist_template_items "
          "(id, template_id, title, item_type, created_at, updated_at) "
          "VALUES ('i1', 't1', 'Computer check', 'equipment', 100, 100)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('pre_dive_checklist_template_items')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('equipment_id'));

    final row = await db
        .customSelect(
          'SELECT title, equipment_id FROM pre_dive_checklist_template_items '
          "WHERE id = 'i1'",
        )
        .getSingle();
    expect(row.data['title'], 'Computer check');
    expect(row.data['equipment_id'], isNull);
  });

  test('migration list includes v186 and schema is at least 186', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(186));
    expect(AppDatabase.migrationVersions, contains(186));
  });

  test('v186 is idempotent when equipment_id already exists', () async {
    // An interrupted upgrade, or a database that reached this version number
    // from a parallel branch, leaves the column already added. The PRAGMA
    // guard must skip the ALTER rather than fail on a duplicate column.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 185');
        rawDb.execute(_preV186TemplateItems);
        rawDb.execute(
          'ALTER TABLE pre_dive_checklist_template_items '
          'ADD COLUMN equipment_id TEXT',
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('pre_dive_checklist_template_items')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')).where((n) => n == 'equipment_id'),
      hasLength(1),
    );
  });

  test(
    'the helper no-ops when pre_dive_checklist_template_items is absent',
    () async {
      // Partial-schema case: migration tests instantiate databases without
      // unrelated tables, and unguarded DDL would fail with "no such table".
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 185');
          // Deliberately no pre_dive_checklist_template_items table at all.
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final result = await db.customSelect('SELECT 1 AS ok').getSingle();
      expect(result.data['ok'], 1);
    },
  );
}
