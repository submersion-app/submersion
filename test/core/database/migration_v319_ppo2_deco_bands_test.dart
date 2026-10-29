import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v319: per-O2-band deco ppO2 limits and the explicit MOD for 100% O2
/// (issue #3580), Dive Planner only. diver_settings gains the toggles and
/// band/depth values, all off/at the flat default; dive_plans gains the
/// matching per-plan overrides, all nullable.
///
/// v321: dive_plans gains the per-plan "explicitly off" flags for the bands
/// and the explicit-depth override (issue #3580 follow-up), both false by
/// default.
///
/// v322: diver_settings gains the hypercapnia-bailout toggle/factor/
/// duration; dive_plans gains the matching per-plan overrides and
/// "explicitly off" flag (issue #3743).
///
/// (v320 is main's nearby_peers rung, issue #3731, between them.)
///
/// All three are column only, every toggle/flag off or at its flat default:
/// no existing diver's planning behavior changes.
void main() {
  Future<Set<String>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  const diverSettingsColumnsV319 = [
    'ppo2_deco_bands_enabled',
    'ppo2_deco_band1',
    'ppo2_deco_band2',
    'ppo2_deco_band3',
    'max_o2_depth_enabled',
    'max_o2_depth_meters',
  ];
  const divePlansColumnsV319 = [
    'ppo2_deco_band1',
    'ppo2_deco_band2',
    'ppo2_deco_band3',
    'max_o2_depth_meters',
  ];
  const divePlansColumnsV321 = [
    'ppo2_deco_bands_explicitly_off',
    'max_o2_depth_explicitly_off',
  ];
  const diverSettingsColumnsV322 = [
    'planner_hypercapnia_enabled',
    'planner_hypercapnia_factor',
    'planner_hypercapnia_minutes',
  ];
  const divePlansColumnsV322 = [
    'hypercapnia_amv',
    'hypercapnia_minutes',
    'hypercapnia_explicitly_off',
  ];

  /// A file stranded at [userVersion] whose diver_settings and dive_plans
  /// lack every column from v319 onward and hold one row each.
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

  for (final version in [319, 321, 322]) {
    test(
      'v$version is at or below the current schema version and in the ladder',
      () {
        expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(version));
        expect(AppDatabase.migrationVersions, contains(version));
        const versions = AppDatabase.migrationVersions;
        final below = versions[versions.indexOf(version) - 1];
        expect(
          AppDatabase.migrationStepCount(below),
          AppDatabase.migrationStepCount(version) + 1,
        );
      },
    );

    test('v$version rung is additive and did not move the sync floor', () {
      expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(version));
    });
  }

  test('a fresh database has every column through v322', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    final diverSettings = await columns(db, 'diver_settings');
    final divePlans = await columns(db, 'dive_plans');
    for (final column in [
      ...diverSettingsColumnsV319,
      ...diverSettingsColumnsV322,
    ]) {
      expect(diverSettings, contains(column), reason: column);
    }
    for (final column in [
      ...divePlansColumnsV319,
      ...divePlansColumnsV321,
      ...divePlansColumnsV322,
    ]) {
      expect(divePlans, contains(column), reason: column);
    }
  });

  test(
    'upgrading from v318 adds every column through v322, all off/flat',
    () async {
      final db = AppDatabase(strandedAt(318));
      addTearDown(db.close);
      final diverSettings = await columns(db, 'diver_settings');
      final divePlans = await columns(db, 'dive_plans');
      for (final column in [
        ...diverSettingsColumnsV319,
        ...diverSettingsColumnsV322,
      ]) {
        expect(diverSettings, contains(column), reason: column);
      }
      for (final column in [
        ...divePlansColumnsV319,
        ...divePlansColumnsV321,
        ...divePlansColumnsV322,
      ]) {
        expect(divePlans, contains(column), reason: column);
      }
      final row = await db
          .customSelect(
            'SELECT ppo2_deco_bands_enabled, max_o2_depth_enabled, '
            'ppo2_deco_band1, max_o2_depth_meters, '
            'planner_hypercapnia_enabled, planner_hypercapnia_factor, '
            'planner_hypercapnia_minutes '
            "FROM diver_settings WHERE id = 's1'",
          )
          .getSingle();
      expect(row.read<int>('ppo2_deco_bands_enabled'), 0);
      expect(row.read<int>('max_o2_depth_enabled'), 0);
      expect(row.read<double>('ppo2_deco_band1'), 1.6);
      expect(row.read<double>('max_o2_depth_meters'), 6.0);
      expect(row.read<int>('planner_hypercapnia_enabled'), 0);
      expect(row.read<double>('planner_hypercapnia_factor'), 4.0);
      expect(row.read<int>('planner_hypercapnia_minutes'), 5);

      final planRow = await db
          .customSelect(
            'SELECT ppo2_deco_bands_explicitly_off, '
            'max_o2_depth_explicitly_off, hypercapnia_explicitly_off '
            "FROM dive_plans WHERE id = 'p1'",
          )
          .getSingle();
      expect(planRow.read<int>('ppo2_deco_bands_explicitly_off'), 0);
      expect(planRow.read<int>('max_o2_depth_explicitly_off'), 0);
      expect(planRow.read<int>('hypercapnia_explicitly_off'), 0);
    },
  );

  test(
    'a database already at v320 (nearby sync shipped first, so the v319 '
    'rung never ran) regains the v319 columns (beforeOpen backstop)',
    () async {
      final db = AppDatabase(strandedAt(320));
      addTearDown(db.close);
      final diverSettings = await columns(db, 'diver_settings');
      final divePlans = await columns(db, 'dive_plans');
      for (final column in diverSettingsColumnsV319) {
        expect(diverSettings, contains(column), reason: column);
      }
      for (final column in divePlansColumnsV319) {
        expect(divePlans, contains(column), reason: column);
      }
    },
  );

  test('a database already at the current schema version without these '
      'columns regains all of them (beforeOpen backstop)', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final diverSettings = await columns(db, 'diver_settings');
    final divePlans = await columns(db, 'dive_plans');
    for (final column in [
      ...diverSettingsColumnsV319,
      ...diverSettingsColumnsV322,
    ]) {
      expect(diverSettings, contains(column), reason: column);
    }
    for (final column in [
      ...divePlansColumnsV319,
      ...divePlansColumnsV321,
      ...divePlansColumnsV322,
    ]) {
      expect(divePlans, contains(column), reason: column);
    }
  });
}
