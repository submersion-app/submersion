import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v206: the condition engine's master and per-rule toggles on
/// `diver_settings` (condition phase 3b). Column-only rung, no backfill.

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// The one table the v206 block touches, as a v203 database would carry it
/// (plus the columns the beforeOpen backstops assert on it).
void _createV203Fixture(dynamic rawDb) {
  rawDb.execute('PRAGMA user_version = 203');
  rawDb.execute('''
    CREATE TABLE diver_settings (
      id TEXT NOT NULL PRIMARY KEY, diver_id TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
  ''');
}

void main() {
  test('v206 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; older rung tests relax to
    // greaterThanOrEqualTo when a newer one lands.
    expect(AppDatabase.currentSchemaVersion, 206);
    expect(AppDatabase.migrationVersions, contains(206));
  });

  test('a fresh database has both toggle columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      await _columns(db, 'diver_settings'),
      containsAll(['condition_engine_enabled', 'condition_disabled_rules']),
    );
  });

  test('a v203 database gains the columns with their defaults', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: _createV203Fixture));
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO diver_settings (id, diver_id, created_at, updated_at) "
      "VALUES ('s1', 'd1', 1, 1)",
    );
    final row = await db
        .customSelect(
          'SELECT condition_engine_enabled AS e, condition_disabled_rules AS r '
          "FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<int>('e'), 1);
    expect(row.data['r'], isNull);
  });

  test(
    'the backstop re-asserts the columns on an already-current file',
    () async {
      // A database restored from a peer at the current version but missing
      // the columns (the parallel-branch collision case) heals on open.
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
            );
            raw.execute('''
            CREATE TABLE diver_settings (
              id TEXT NOT NULL PRIMARY KEY, diver_id TEXT NOT NULL,
              created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
          ''');
          },
        ),
      );
      addTearDown(db.close);
      expect(
        await _columns(db, 'diver_settings'),
        containsAll(['condition_engine_enabled', 'condition_disabled_rules']),
      );
    },
  );
}
