import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v307: diver_settings gains the air-break/turn-pressure global
/// defaults, and dive_plans gains the explicit air-breaks-off override
/// (issue #3552, follow-up to v304-306). Unlike v304's columns, these stay
/// nullable - null means "no policy"/"no rule", matching today's behaviour
/// for a diver who has not opted in to one. Renumbered from 305 as #3482
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
      rawDb.execute(
        'CREATE TABLE dive_plans (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, gf_low INTEGER NOT NULL, '
        'gf_high INTEGER NOT NULL, created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO dive_plans (id, name, gf_low, gf_high, created_at, "
        "updated_at) VALUES ('p1', 'plan', 50, 80, 0, 0)",
      );
    },
  );

  const diverSettingsColumns = [
    'planner_turn_pressure_rule',
    'planner_turn_pressure_fraction',
    'planner_air_break_o2_seconds',
    'planner_air_break_break_seconds',
  ];

  test('v307 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(307));
    expect(AppDatabase.migrationVersions, contains(307));
    expect(
      AppDatabase.migrationStepCount(306),
      AppDatabase.migrationStepCount(307) + 1,
    );
  });

  test('the columns are additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(307));
  });

  test(
    'upgrading from v306 adds the diver_settings defaults as null',
    () async {
      final db = AppDatabase(dbAt(306));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT ${diverSettingsColumns.join(", ")} FROM diver_settings',
          )
          .getSingle();
      for (final column in diverSettingsColumns) {
        expect(row.data[column], isNull, reason: column);
      }
    },
  );

  test('upgrading from v306 adds dive_plans.air_breaks_explicitly_off as '
      'false for an existing row', () async {
    final db = AppDatabase(dbAt(306));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          'SELECT air_breaks_explicitly_off FROM dive_plans WHERE id = ?',
          variables: [const Variable('p1')],
        )
        .getSingle();
    expect(row.read<bool>('air_breaks_explicitly_off'), isFalse);
  });

  test('beforeOpen heals a database already at v307 that lacks them', () async {
    final db = AppDatabase(dbAt(307));
    addTearDown(db.close);
    final diverSettingsCols =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    for (final column in diverSettingsColumns) {
      expect(diverSettingsCols, contains(column), reason: column);
    }
    final divePlansCols =
        (await db.customSelect("PRAGMA table_info('dive_plans')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(divePlansCols, contains('air_breaks_explicitly_off'));
  });
}
