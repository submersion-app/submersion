import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v348 adds `dive_derived_metrics.gas_use_s` and `gas_use_avg_depth_m`
/// (issue #2930): how long a dive was underwater with surface runs at the
/// ends left out, and the mean depth over that time, which whole-dive SAC and
/// RMV divide by. Nullable on a device-local cache with no backfill: the
/// derived metrics engine version bump makes the sweep rebuild every row.
void main() {
  test('v348 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(348));
    expect(AppDatabase.migrationVersions, contains(348));
  });

  test('the compatibility floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(348));
  });

  test('a fresh database has both columns, nullable', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_derived_metrics')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName['gas_use_s']!.read<String>('type'), 'INTEGER');
    expect(byName['gas_use_s']!.read<int>('notnull'), 0);
    expect(byName['gas_use_avg_depth_m']!.read<String>('type'), 'REAL');
    expect(byName['gas_use_avg_depth_m']!.read<int>('notnull'), 0);
    for (final column in [
      'surface_breathed_from_s',
      'surface_breathed_until_s',
    ]) {
      expect(byName[column]!.read<String>('type'), 'INTEGER');
      expect(byName[column]!.read<int>('notnull'), 0);
    }
  });

  test('a cylinder gains surface breathing minutes, empty', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        registerAppSqlFunctions(rawDb);
        rawDb.execute('PRAGMA user_version = 347');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL)
        ''');
        rawDb.execute("INSERT INTO dive_tanks VALUES ('t1', 'd1')");
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dive_tanks')").get();
    final column = cols.singleWhere(
      (c) => c.read<String>('name') == 'surface_breathing_duration',
    );
    expect(column.read<String>('type'), 'INTEGER');
    expect(column.read<int>('notnull'), 0);
    final row = await db
        .customSelect(
          "SELECT surface_breathing_duration FROM dive_tanks WHERE id = 't1'",
        )
        .getSingle();
    expect(row.data['surface_breathing_duration'], isNull);
  });

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing row upgrades with no window', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        registerAppSqlFunctions(rawDb);
        rawDb.execute('PRAGMA user_version = 347');
        rawDb.execute('''
          CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)
        ''');
        rawDb.execute('''
          CREATE TABLE dive_derived_metrics (
            dive_id TEXT NOT NULL PRIMARY KEY,
            engine_version INTEGER NOT NULL,
            source_updated_at INTEGER NOT NULL,
            computed_at INTEGER NOT NULL)
        ''');
        rawDb.execute(
          'INSERT INTO dive_derived_metrics '
          "VALUES ('d1', 3, 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT gas_use_s, gas_use_avg_depth_m FROM dive_derived_metrics '
          "WHERE dive_id = 'd1'",
        )
        .getSingle();
    expect(row.data['gas_use_s'], isNull);
    expect(row.data['gas_use_avg_depth_m'], isNull);
  });
}
