import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Reads the SQL default expression declared for [column] on [table] and asks
/// SQLite to evaluate it, so the assertion holds whichever literal spelling
/// (`0`, `FALSE`, ...) the DDL happens to use. Returns null when the column
/// declares no default at all.
Future<int?> _defaultAsInt(AppDatabase db, String table, String column) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  final row = cols.firstWhere((c) => c.read<String>('name') == column);
  final expression = row.read<String?>('dflt_value');
  if (expression == null) return null;
  final evaluated = await db
      .customSelect('SELECT ($expression) AS value')
      .getSingle();
  return evaluated.read<int>('value');
}

void main() {
  test('v156 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(156));
    expect(AppDatabase.migrationVersions, contains(156));
  });

  test('a fresh database has dive_plan_tanks.is_travel_gas', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_plan_tanks')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('is_travel_gas'));
  });

  test('the column is not null and defaults false', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_plan_tanks')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'is_travel_gas',
    );
    expect(column.read<int>('notnull'), 1);
    // A NOT NULL column with no default would break inserts from older
    // writers, and a default of true would silently flag every existing
    // cylinder as travel gas, so pin the value rather than just its presence.
    expect(await _defaultAsInt(db, 'dive_plan_tanks', 'is_travel_gas'), 0);
  });

  test(
    'a database stranded before v156 gains the column via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dive_plan_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            plan_id TEXT NOT NULL,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('dive_plan_tanks')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('is_travel_gas'));
      // The backstop's ALTER TABLE spells its own default, independently of the
      // table definition above, so pin that one too.
      expect(await _defaultAsInt(db, 'dive_plan_tanks', 'is_travel_gas'), 0);
    },
  );

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
