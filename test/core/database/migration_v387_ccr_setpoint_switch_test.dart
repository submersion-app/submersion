import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v387: `diver_settings.ccr_setpoint_switch_depth` (REAL, default 10 m)
/// and `dive_plans.setpoint_switch_off` (boolean, default off), issue #3793.
/// Defaulted, no backfill, so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool withColumns = false}) {
    final settingsExtra = withColumns
        ? ', ccr_setpoint_switch_depth REAL NOT NULL DEFAULT 10.0'
        : '';
    final planExtra = withColumns
        ? ', setpoint_switch_off INTEGER NOT NULL DEFAULT 0'
        : '';
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $version');
        rawDb.execute(
          'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
          'diver_id TEXT NOT NULL$settingsExtra)',
        );
        rawDb.execute(
          'CREATE TABLE dive_plans (id TEXT NOT NULL PRIMARY KEY, '
          'name TEXT NOT NULL$planExtra)',
        );
        if (withColumns) {
          rawDb.execute(
            'INSERT INTO diver_settings '
            "(id, diver_id, ccr_setpoint_switch_depth) VALUES ('s1', 'd1', 6.5)",
          );
          rawDb.execute(
            'INSERT INTO dive_plans (id, name, setpoint_switch_off) '
            "VALUES ('p1', 'Plan', 1)",
          );
        } else {
          rawDb.execute(
            "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
          );
          rawDb.execute(
            "INSERT INTO dive_plans (id, name) VALUES ('p1', 'Plan')",
          );
        }
      },
    );
  }

  Future<Map<String, Object?>> storedSettings(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT ccr_setpoint_switch_depth FROM diver_settings',
              )
              .getSingle())
          .data;

  Future<Map<String, Object?>> storedPlan(AppDatabase db) async =>
      (await db
              .customSelect('SELECT setpoint_switch_off FROM dive_plans')
              .getSingle())
          .data;

  test('v387 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(387));
    expect(AppDatabase.migrationVersions, contains(387));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(387));
  });

  test(
    'upgrading from v386 gives an existing diver the 10 m default',
    () async {
      final db = AppDatabase(dbAt(386));
      addTearDown(db.close);
      expect(await storedSettings(db), {'ccr_setpoint_switch_depth': 10.0});
    },
  );

  test('upgrading from v386 leaves an existing plan switching', () async {
    final db = AppDatabase(dbAt(386));
    addTearDown(db.close);
    expect(await storedPlan(db), {'setpoint_switch_off': 0});
  });

  test('the upgraded flag is a boolean', () async {
    final db = AppDatabase(dbAt(386));
    addTearDown(db.close);
    await storedPlan(db);
    await expectLater(
      db.customStatement('UPDATE dive_plans SET setpoint_switch_off = 2'),
      throwsA(anything),
    );
  });

  test('a database already carrying the columns keeps its values', () async {
    final db = AppDatabase(dbAt(386, withColumns: true));
    addTearDown(db.close);
    expect(await storedSettings(db), {'ccr_setpoint_switch_depth': 6.5});
    expect(await storedPlan(db), {'setpoint_switch_off': 1});
  });
}
