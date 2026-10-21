import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v304: diver_settings gains the planner Setup-accordion global
/// defaults (Deco rates, Gas/SAC, Contingency, DPV team policy) so a new
/// plan's Setup fields resolve from Settings instead of hardcoded
/// constructor defaults (issue #3552). Renumbered from 302 as #3482
/// shipped 302-303 first.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  const newColumns = <String, Object>{
    'planner_descent_rate': 18.0,
    'planner_ascent_rate': 9.0,
    'planner_intermediate_ascent_rate': 6.0,
    'planner_shallow_ascent_rate': 3.0,
    'planner_final_ascent_rate': 1.0,
    'planner_gas_switch_stop_seconds': 0,
    'planner_sac_bottom': 15.0,
    'planner_sac_deco': 15.0,
    'planner_sac_stressed_factor': 2.5,
    'planner_buddy_factor': 2.0,
    'planner_problem_solving_minutes': 2,
    'planner_best_mix_end_meters': 30.0,
    'planner_deviation_depth_delta': 5.0,
    'planner_deviation_time_minutes': 5,
    'planner_battery_reserve_fraction': 1.0 / 3.0,
    'planner_walk_speed_mps': 0.8,
  };

  test('v304 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(304));
    expect(AppDatabase.migrationVersions, contains(304));
    expect(
      AppDatabase.migrationStepCount(303),
      AppDatabase.migrationStepCount(304) + 1,
    );
  });

  test('the columns are additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(304));
  });

  test(
    'upgrading from v303 adds every column with its documented default',
    () async {
      final db = AppDatabase(dbAt(303));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT ${newColumns.keys.join(", ")} FROM diver_settings',
          )
          .getSingle();
      for (final entry in newColumns.entries) {
        final value = row.data[entry.key];
        if (entry.value is double) {
          expect(
            (value as num).toDouble(),
            closeTo(entry.value as double, 0.0001),
            reason: entry.key,
          );
        } else {
          expect(value, entry.value, reason: entry.key);
        }
      }
    },
  );

  test('beforeOpen heals a database already at v304 that lacks them', () async {
    final db = AppDatabase(dbAt(304));
    addTearDown(db.close);
    final cols =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    for (final column in newColumns.keys) {
      expect(cols, contains(column), reason: column);
    }
  });
}
