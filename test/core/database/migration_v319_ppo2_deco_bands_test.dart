import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v319: per-O2-band deco ppO2 limits and the explicit MOD for 100% O2
/// (issue #3580), Dive Planner only. diver_settings gains the toggles and
/// band/depth values, all off/at the flat default; dive_plans gains the
/// matching per-plan overrides, all nullable. Column only, both off by
/// default: no existing diver's planning behavior changes.
void main() {
  Future<Set<String>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  const diverSettingsColumns = [
    'ppo2_deco_bands_enabled',
    'ppo2_deco_band1',
    'ppo2_deco_band2',
    'ppo2_deco_band3',
    'max_o2_depth_enabled',
    'max_o2_depth_meters',
  ];
  const divePlansColumns = [
    'ppo2_deco_band1',
    'ppo2_deco_band2',
    'ppo2_deco_band3',
    'max_o2_depth_meters',
  ];

  /// A file stranded at [userVersion] whose diver_settings and dive_plans
  /// lack the new columns and hold one row each.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'ppo2_max_working REAL NOT NULL DEFAULT 1.4, '
        'ppo2_max_deco REAL NOT NULL DEFAULT 1.6)',
      );
      rawDb.execute("INSERT INTO diver_settings (id) VALUES ('s1')");
      rawDb.execute('CREATE TABLE dive_plans (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute("INSERT INTO dive_plans (id) VALUES ('p1')");
    },
  );

  test('v319 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(319));
    expect(AppDatabase.migrationVersions, contains(319));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(319) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(319) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(319));
  });

  test('a fresh database has every column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    final diverSettings = await columns(db, 'diver_settings');
    final divePlans = await columns(db, 'dive_plans');
    for (final column in diverSettingsColumns) {
      expect(diverSettings, contains(column), reason: column);
    }
    for (final column in divePlansColumns) {
      expect(divePlans, contains(column), reason: column);
    }
  });

  test('upgrading from v318 adds every column, both toggles off', () async {
    final db = AppDatabase(strandedAt(318));
    addTearDown(db.close);
    final diverSettings = await columns(db, 'diver_settings');
    final divePlans = await columns(db, 'dive_plans');
    for (final column in diverSettingsColumns) {
      expect(diverSettings, contains(column), reason: column);
    }
    for (final column in divePlansColumns) {
      expect(divePlans, contains(column), reason: column);
    }
    final row = await db
        .customSelect(
          'SELECT ppo2_deco_bands_enabled, max_o2_depth_enabled, '
          'ppo2_deco_band1, max_o2_depth_meters '
          "FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<int>('ppo2_deco_bands_enabled'), 0);
    expect(row.read<int>('max_o2_depth_enabled'), 0);
    expect(row.read<double>('ppo2_deco_band1'), 1.6);
    expect(row.read<double>('max_o2_depth_meters'), 6.0);
  });

  test('a database already at v319 without the columns regains them', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final diverSettings = await columns(db, 'diver_settings');
    final divePlans = await columns(db, 'dive_plans');
    for (final column in diverSettingsColumns) {
      expect(diverSettings, contains(column), reason: column);
    }
    for (final column in divePlansColumns) {
      expect(divePlans, contains(column), reason: column);
    }
  });
}
