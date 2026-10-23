import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v308: reserve pressure and gradient factors join the live-resolve
/// group (issue #3552, follow-up to v304-307). dive_plans.reserve_pressure/
/// gf_low/gf_high made nullable (table rebuild, same technique as v305),
/// diver_settings gains the reserve-pressure default (gfLow/gfHigh already
/// had one via gfLowProvider/gfHighProvider). Renumbered from 306 as #3482
/// shipped 302-303 first.
void main() {
  NativeDatabase dbAt(int version, {String pressureUnit = 'bar'}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE diver_settings ("id" TEXT NOT NULL PRIMARY KEY, '
            '"diver_id" TEXT NOT NULL, '
            '"pressure_unit" TEXT NOT NULL DEFAULT \'bar\')',
          );
          rawDb.execute(
            "INSERT INTO diver_settings (id, diver_id, pressure_unit) "
            "VALUES ('s1', 'd1', '$pressureUnit')",
          );
          rawDb.execute(
            'CREATE TABLE dive_plans ("id" TEXT NOT NULL PRIMARY KEY, '
            '"name" TEXT NOT NULL, "gf_low" INTEGER NOT NULL, '
            '"gf_high" INTEGER NOT NULL, '
            '"reserve_pressure" REAL NOT NULL DEFAULT 50.0, '
            '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL)',
          );
          rawDb.execute(
            "INSERT INTO dive_plans (id, name, gf_low, gf_high, "
            "reserve_pressure, created_at, updated_at) VALUES "
            "('p1', 'plan', 45, 80, 60.0, 0, 0)",
          );
        },
      );

  test('v308 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(308));
    expect(AppDatabase.migrationVersions, contains(308));
    expect(
      AppDatabase.migrationStepCount(307),
      AppDatabase.migrationStepCount(308) + 1,
    );
  });

  // NULL now means "follow Settings", which a pre-305 reader's
  // non-nullable fromJson cannot decode, so v305-v308 hold older peers.
  test('the nullable columns raise the sync floor to 308', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test(
    'upgrading from v307 keeps the row\'s existing values unchanged',
    () async {
      final db = AppDatabase(dbAt(307));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT gf_low, gf_high, reserve_pressure FROM dive_plans '
            'WHERE id = ?',
            variables: [const Variable('p1')],
          )
          .getSingle();
      expect(row.read<int>('gf_low'), 45);
      expect(row.read<int>('gf_high'), 80);
      expect(row.read<double>('reserve_pressure'), 60.0);
    },
  );

  test(
    'upgrading from v307 lets every rebuilt column accept an explicit NULL',
    () async {
      final db = AppDatabase(dbAt(307));
      addTearDown(db.close);
      await db.customStatement(
        'UPDATE dive_plans SET gf_low = NULL, gf_high = NULL, '
        'reserve_pressure = NULL WHERE id = ?',
        ['p1'],
      );
      final row = await db
          .customSelect(
            'SELECT gf_low, gf_high, reserve_pressure FROM dive_plans '
            'WHERE id = ?',
            variables: [const Variable('p1')],
          )
          .getSingle();
      expect(row.read<int?>('gf_low'), isNull);
      expect(row.read<int?>('gf_high'), isNull);
      expect(row.read<double?>('reserve_pressure'), isNull);
    },
  );

  test('upgrading from v307 adds the diver_settings reserve default as 50.0 '
      'for a metric diver', () async {
    final db = AppDatabase(dbAt(307));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT planner_reserve_pressure FROM diver_settings')
        .getSingle();
    expect(row.read<double>('planner_reserve_pressure'), 50.0);
  });

  test(
    'upgrading from v307 backfills the diver_settings reserve default to '
    "the pre-migration imperial convention (500 psi) for a 'psi' diver",
    () async {
      final db = AppDatabase(dbAt(307, pressureUnit: 'psi'));
      addTearDown(db.close);
      final row = await db
          .customSelect('SELECT planner_reserve_pressure FROM diver_settings')
          .getSingle();
      expect(
        row.read<double>('planner_reserve_pressure'),
        closeTo(500.0 / 14.5038, 0.0001),
      );
    },
  );

  test('beforeOpen heals a database already at v308 that lacks it', () async {
    final db = AppDatabase(dbAt(308));
    addTearDown(db.close);
    final cols =
        (await db.customSelect("PRAGMA table_info('dive_plans')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(cols, contains('gf_low'));
    expect(cols, contains('gf_high'));
    expect(cols, contains('reserve_pressure'));
    final diverSettingsCols =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(diverSettingsCols, contains('planner_reserve_pressure'));
  });
}
