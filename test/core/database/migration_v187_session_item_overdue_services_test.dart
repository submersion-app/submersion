import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Pre-v187 pre_dive_session_items shape: no frozen overdue-services column.
const _preV187SessionItems = '''
  CREATE TABLE pre_dive_session_items (
    id TEXT NOT NULL PRIMARY KEY,
    session_id TEXT NOT NULL,
    title TEXT NOT NULL,
    item_type TEXT NOT NULL DEFAULT 'check',
    state TEXT NOT NULL DEFAULT 'pending',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';

void main() {
  test('v187 adds the overdue_services column, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 186');
        rawDb.execute(_preV187SessionItems);
        rawDb.execute(
          "INSERT INTO pre_dive_session_items "
          "(id, session_id, title, item_type, state, created_at, updated_at) "
          "VALUES ('i1', 's1', 'Cell check', 'check', 'flagged', 100, 100)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('pre_dive_session_items')")
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('overdue_services'),
    );

    final row = await db
        .customSelect(
          'SELECT title, overdue_services FROM pre_dive_session_items '
          "WHERE id = 'i1'",
        )
        .getSingle();
    expect(row.data['title'], 'Cell check');
    expect(row.data['overdue_services'], isNull);
  });

  test('migration list includes v187 and schema is at least 187', () {
    // Relaxed from an exact match when v188 landed: the exact assertion is
    // the newest rung's job, and it moves with it.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(187));
    expect(AppDatabase.migrationVersions, contains(187));
  });

  test('v187 is idempotent when overdue_services already exists', () async {
    // An interrupted upgrade, or a database that reached this version number
    // from a parallel branch, leaves the column already added. The PRAGMA
    // guard must skip the ALTER rather than fail on a duplicate column.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 186');
        rawDb.execute(_preV187SessionItems);
        rawDb.execute(
          'ALTER TABLE pre_dive_session_items ADD COLUMN overdue_services TEXT',
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('pre_dive_session_items')")
        .get();
    expect(
      cols
          .map((c) => c.read<String>('name'))
          .where((n) => n == 'overdue_services'),
      hasLength(1),
    );
  });

  test('the helper no-ops when pre_dive_session_items is absent', () async {
    // Partial-schema case: migration tests instantiate databases without
    // unrelated tables, and unguarded DDL would fail with "no such table".
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 186');
        // Deliberately no pre_dive_session_items table at all.
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final result = await db.customSelect('SELECT 1 AS ok').getSingle();
    expect(result.data['ok'], 1);
  });
}
