import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v362 adds dive_deco_status: the computed deco verdicts the query
/// language's deco field reads (#4461).
Future<Set<String>> _tables(AppDatabase db) async => {
  for (final r
      in await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get())
    r.read<String>('name'),
};

void main() {
  test('v362 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(362));
    expect(AppDatabase.migrationVersions, contains(362));
    expect(AppDatabase.migrationStepCount(361), greaterThanOrEqualTo(1));
  });

  test('a fresh database has the cache table and no hlc column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await _tables(db), contains('dive_deco_status'));
    final cols = await db
        .customSelect("PRAGMA table_info('dive_deco_status')")
        .get();
    // A local cache: sync never reads or writes it.
    expect(cols.map((c) => c.read<String>('name')), isNot(contains('hlc')));
  });

  test('a database already at the current version gains the table', () async {
    // Only the beforeOpen backstop can add it there (a restore or a
    // sync-adopt never runs onUpgrade).
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          raw.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        },
      ),
    );
    addTearDown(db.close);
    expect(await _tables(db), contains('dive_deco_status'));
  });
}
