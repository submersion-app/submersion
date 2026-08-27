import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v168 adds `buddies.is_favorite` (issue #638): a diver can pin frequently
/// dived buddies to the top of the "Add buddy" picker regardless of the
/// chosen sort. NOT NULL with a false default, so every pre-existing buddy
/// reads back as not-favorited.
void main() {
  test('v168 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(168));
    expect(AppDatabase.migrationVersions, contains(168));
  });

  test('a fresh database has buddies.is_favorite', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('buddies')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('is_favorite'));
  });

  test('the column is NOT NULL with a false default', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('buddies')").get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'is_favorite',
    );
    expect(column.read<int>('notnull'), 1);
    expect(column.read<String?>('dflt_value'), '0');
  });

  test('a database stranded at v160 gains the column via onUpgrade and '
      'existing rows default to not-favorited', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 160');
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            email TEXT, phone TEXT, photo_path TEXT,
            notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO buddies (id, name, created_at, updated_at) "
          "VALUES ('b1', 'B1', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('buddies')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('is_favorite'));

    final row = await db
        .customSelect("SELECT is_favorite FROM buddies WHERE id = 'b1'")
        .getSingle();
    expect(row.read<int>('is_favorite'), 0);
  });

  test('beforeOpen backstop adds the column when a parallel-branch collision '
      'stranded a DB past v168 without running the onUpgrade block', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            email TEXT, phone TEXT, photo_path TEXT,
            notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('buddies')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('is_favorite'));
  });

  test('the assert is a no-op when the buddies table is absent', () async {
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
