import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v314: cylinder_config_items.deco_switch_depth (issue #3567, renumbered from
/// v304, which #3552 took), the MOD a
/// diver set by hand on a saved cylinder. Column only, no backfill: existing
/// rows read null, which means the cylinder uses its default MOD. The sync
/// floor does not move: an older peer omits the column, and an omitted
/// column keeps this device's value.
void main() {
  Future<Set<String>> columns(AppDatabase db) async {
    final rows = await db
        .customSelect("PRAGMA table_info('cylinder_config_items')")
        .get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// A file stranded at [userVersion] whose cylinder_config_items lacks the
  /// column and holds one row.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE cylinder_config_items (id TEXT NOT NULL PRIMARY KEY, '
        'config_id TEXT NOT NULL, tank_role TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO cylinder_config_items (id, config_id, tank_role) "
        "VALUES ('i1', 'c1', 'deco')",
      );
    },
  );

  Future<double?> modOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          "SELECT deco_switch_depth FROM cylinder_config_items WHERE id = '$id'",
        )
        .getSingle();
    return row.read<double?>('deco_switch_depth');
  }

  test('v314 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(314));
    expect(AppDatabase.migrationVersions, contains(314));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(314) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(314) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(314));
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await columns(db), contains('deco_switch_depth'));
  });

  test(
    'upgrading from v313 adds the column; existing rows read null',
    () async {
      final db = AppDatabase(strandedAt(313));
      addTearDown(db.close);
      expect(await columns(db), contains('deco_switch_depth'));
      expect(await modOf(db, 'i1'), isNull);
    },
  );

  test('a database already at v314 without the column regains it', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columns(db), contains('deco_switch_depth'));
  });
}
