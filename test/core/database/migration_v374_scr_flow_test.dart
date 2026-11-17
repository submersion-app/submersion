import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v374: a plan's own SCR injection rate, SCR VO2 and pSCR VO2
/// (`dive_plans`, nullable: null follows the diver), and the diver's defaults
/// for them (`diver_settings`, defaulted to the figures every plan used
/// before) (issue #4660). Columns only, no backfill, so the floor holds.
void main() {
  NativeDatabase dbAt(
    int version, {
    double? storedScrVo2,
  }) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute('CREATE TABLE dive_plans (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute("INSERT INTO dive_plans (id) VALUES ('p1')");
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL'
        "${storedScrVo2 != null ? ', planner_scr_vo2 REAL NOT NULL DEFAULT 1.3' : ''})",
      );
      rawDb.execute(
        storedScrVo2 != null
            ? 'INSERT INTO diver_settings (id, diver_id, planner_scr_vo2) '
                  "VALUES ('s1', 'd1', $storedScrVo2)"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  Future<Map<String, Object?>> row(AppDatabase db, String sql) async =>
      (await db.customSelect(sql).getSingle()).data;

  test('v374 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(374));
    expect(AppDatabase.migrationVersions, contains(374));
  });

  test('the floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(374));
  });

  test('upgrading adds empty plan columns', () async {
    final db = AppDatabase(dbAt(373));
    addTearDown(db.close);
    final plan = await row(
      db,
      'SELECT scr_injection_rate, scr_vo2, pscr_vo2 FROM dive_plans',
    );
    expect(plan['scr_injection_rate'], isNull);
    expect(plan['scr_vo2'], isNull);
    expect(plan['pscr_vo2'], isNull);
  });

  test(
    'upgrading defaults the diver columns to the old fixed figures',
    () async {
      final db = AppDatabase(dbAt(373));
      addTearDown(db.close);
      final settings = await row(
        db,
        'SELECT planner_scr_injection_rate, planner_scr_vo2, planner_pscr_vo2 '
        'FROM diver_settings',
      );
      expect(settings['planner_scr_injection_rate'], 12.0);
      expect(settings['planner_scr_vo2'], 1.3);
      expect(settings['planner_pscr_vo2'], 0.72);
    },
  );

  test('an existing value is kept', () async {
    final db = AppDatabase(dbAt(373, storedScrVo2: 2.0));
    addTearDown(db.close);
    final settings = await row(
      db,
      'SELECT planner_scr_vo2 FROM diver_settings',
    );
    expect(settings['planner_scr_vo2'], 2.0);
  });
}
