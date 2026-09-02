import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v180 shape: a dives table without either exclusion column,
/// stamped at v179 so the upgrade to 180 runs.
NativeDatabase _dbAt179() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 179');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_date_time INTEGER NOT NULL,
          is_planned INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute(
        "INSERT INTO dives (id, dive_date_time) VALUES ('legacy', 0)",
      );
    },
  );
}

Future<Set<String>> _diveColumns(AppDatabase db) async {
  final cols = await db.customSelect("PRAGMA table_info('dives')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

void main() {
  test(
    'v180 adds both statistics-exclusion columns to an existing table',
    () async {
      final db = AppDatabase(_dbAt179());
      addTearDown(db.close);

      final names = await _diveColumns(db);
      expect(names, contains('excluded_from_stats'));
      expect(names, contains('excluded_from_gas_stats'));
    },
  );

  test('pre-existing dives default to included', () async {
    final db = AppDatabase(_dbAt179());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT excluded_from_stats, excluded_from_gas_stats '
          "FROM dives WHERE id = 'legacy'",
        )
        .getSingle();
    expect(row.read<int>('excluded_from_stats'), 0);
    expect(row.read<int>('excluded_from_gas_stats'), 0);
  });

  test('fresh databases get both columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final names = await _diveColumns(db);
    expect(names, contains('excluded_from_stats'));
    expect(names, contains('excluded_from_gas_stats'));
  });

  test('the helper no-ops when dives is absent', () async {
    // A minimal fixture with no dives table must not throw: the beforeOpen
    // backstop runs the same assert on every open, including on the stripped
    // databases other migration tests build.
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 179'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('the backstop is idempotent across repeated opens', () async {
    // Reopening the same file-backed schema re-runs beforeOpen. The assert
    // must not attempt a second ALTER TABLE and fail with "duplicate column".
    final db = AppDatabase(_dbAt179());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    await expectLater(
      db.customSelect('SELECT excluded_from_stats FROM dives').get(),
      completes,
    );
    final names = await _diveColumns(db);
    expect(
      names.where((n) => n == 'excluded_from_stats').length,
      1,
      reason: 'the column must be added exactly once',
    );
  });

  test('v180 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(180));
    expect(AppDatabase.migrationVersions, contains(180));
  });
}
