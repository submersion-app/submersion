import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v173 shape: a dive_types table without the short_name column,
/// stamped at v161 so the 161->173 upgrade runs.
NativeDatabase _dbAt161() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 161');
      rawDb.execute('''
        CREATE TABLE dive_types (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          is_built_in INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute(
        "INSERT INTO dive_types (id, name, is_built_in, created_at, updated_at) "
        "VALUES ('wreck', 'Wreck', 1, 1000, 1000)",
      );
    },
  );
}

void main() {
  test('v173 adds dive_types.short_name, preserving existing rows', () async {
    final db = AppDatabase(_dbAt161());
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('dive_types')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('short_name'));

    final row = await db
        .customSelect("SELECT short_name FROM dive_types WHERE id = 'wreck'")
        .getSingle();
    expect(row.data['short_name'], isNull);
  });

  test('fresh databases get the dive_types.short_name column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('dive_types')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('short_name'));
  });

  test('the helper no-ops when dive_types is absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 161'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v173 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(173));
    expect(AppDatabase.migrationVersions, contains(173));
  });
}
