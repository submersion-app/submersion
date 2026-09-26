import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v234 adds saved_queries: a diver's named query trees (#2365, spec
/// Unit 7). Table-only rung, additive, floor stays at 224.

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v234 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 234);
    expect(AppDatabase.migrationVersions, contains(234));
    expect(AppDatabase.migrationStepCount(231), 1);
  });

  test(
    'a fresh database has saved_queries, its columns and its index',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await _tables(db), contains('saved_queries'));
      expect(await _columns(db, 'saved_queries'), {
        'id',
        'diver_id',
        'subject',
        'name',
        'query_json',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      });
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'saved_queries'",
          )
          .get();
      expect(
        indexes.map((r) => r.read<String>('name')),
        contains('idx_saved_queries_diver'),
      );
    },
  );

  test('a database stranded before v234 gains the table', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 231');
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('saved_queries'));
  });

  test('the backstop skips a fixture with no divers table', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 231'),
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);
    // No throw: the helper returns early when the parent is missing.
    expect(await _tables(db), isNot(contains('saved_queries')));
  });
}
