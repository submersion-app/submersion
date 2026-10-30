import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v306: dive_plan_missions.battery_reserve_fraction and
/// .walk_speed_mps made nullable, the DPV Team counterpart of the v305
/// dive_plans rebuild (issue #3552). Renumbered from 304 as #3482 shipped
/// 302-303 first.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE dive_plans (id TEXT NOT NULL PRIMARY KEY, '
        "name TEXT NOT NULL, gf_low INTEGER NOT NULL, "
        'gf_high INTEGER NOT NULL, created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO dive_plans (id, name, gf_low, gf_high, created_at, "
        "updated_at) VALUES ('p1', 'Mission plan', 50, 80, 0, 0)",
      );
      rawDb.execute(
        'CREATE TABLE dive_plan_missions ("id" TEXT NOT NULL PRIMARY KEY, '
        '"plan_id" TEXT NOT NULL, '
        '"battery_reserve_fraction" REAL NOT NULL, '
        '"environment" TEXT NOT NULL DEFAULT \'overhead\', '
        '"walk_speed_mps" REAL NOT NULL DEFAULT 0.8, '
        '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO dive_plan_missions (id, plan_id, "
        "battery_reserve_fraction, walk_speed_mps, created_at, updated_at) "
        "VALUES ('m1', 'p1', 0.5, 1.2, 0, 0)",
      );
    },
  );

  test('v306 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(306));
    expect(AppDatabase.migrationVersions, contains(306));
    expect(
      AppDatabase.migrationStepCount(305),
      AppDatabase.migrationStepCount(306) + 1,
    );
  });

  // NULL now means "follow Settings", which a pre-305 reader's
  // non-nullable fromJson cannot decode, so v305-v308 hold older peers.
  test('the nullable columns raise the sync floor to 308', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test(
    'upgrading from v305 drops NOT NULL and keeps every existing value',
    () async {
      final db = AppDatabase(dbAt(305));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT battery_reserve_fraction, walk_speed_mps '
            'FROM dive_plan_missions WHERE id = ?',
            variables: [const Variable('m1')],
          )
          .getSingle();
      expect(row.read<double>('battery_reserve_fraction'), 0.5);
      expect(row.read<double>('walk_speed_mps'), 1.2);
      // The migrated column must now accept an explicit NULL.
      await db.customStatement(
        'UPDATE dive_plan_missions SET battery_reserve_fraction = NULL, '
        'walk_speed_mps = NULL WHERE id = ?',
        ['m1'],
      );
      final updated = await db
          .customSelect(
            'SELECT battery_reserve_fraction, walk_speed_mps '
            'FROM dive_plan_missions WHERE id = ?',
            variables: [const Variable('m1')],
          )
          .getSingle();
      expect(updated.read<double?>('battery_reserve_fraction'), isNull);
      expect(updated.read<double?>('walk_speed_mps'), isNull);
    },
  );

  test('beforeOpen heals a database already at v306 that lacks it', () async {
    final db = AppDatabase(dbAt(306));
    addTearDown(db.close);
    await db.customStatement(
      'UPDATE dive_plan_missions SET battery_reserve_fraction = NULL '
      'WHERE id = ?',
      ['m1'],
    );
    final row = await db
        .customSelect(
          'SELECT battery_reserve_fraction FROM dive_plan_missions '
          'WHERE id = ?',
          variables: [const Variable('m1')],
        )
        .getSingle();
    expect(row.read<double?>('battery_reserve_fraction'), isNull);
  });
}
