import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v393: the built-in "BCD/wing inspection" kind applies to wings
/// (issue #5110).
///
/// The kind was seeded for `bcd` only, so a diver who entered a standalone
/// wing could offer it nothing but "General service". The wing is the
/// bladder, inflator and OPV that the inspection covers; a backplate and a
/// harness are hardware and stay out.
void main() {
  const bcdWingTypes = '["bcd","wing"]';

  /// A v392 database whose built-in kind carries the pre-v393 type list.
  /// Minimal parents: the beforeOpen backstops heal the rest.
  NativeDatabase setupDb() {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 392');
        rawDb.execute('''
          CREATE TABLE service_kinds (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            applicable_types TEXT NOT NULL DEFAULT '[]',
            default_interval_days INTEGER, default_interval_dives INTEGER,
            default_interval_hours REAL,
            exposure_intervals TEXT NOT NULL DEFAULT '{}',
            default_cost REAL, default_currency TEXT, default_category TEXT,
            auto_attach INTEGER NOT NULL DEFAULT 0,
            is_built_in INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
            hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO service_kinds (id, name, applicable_types, "
          "default_interval_days, auto_attach, default_category, "
          "exposure_intervals, is_built_in, created_at, updated_at) VALUES "
          "('bcd-inspection', 'BCD/wing inspection', '[\"bcd\"]', 365, 1, "
          "'inspection', '{}', 1, 5, 5)",
        );
        // A diver's own kind scoped to BCDs: never widened.
        rawDb.execute(
          "INSERT INTO service_kinds (id, name, applicable_types, "
          "is_built_in, created_at, updated_at) VALUES "
          "('custom-bcd', 'Inflator rebuild', '[\"bcd\"]', 0, 5, 5)",
        );
      },
    );
  }

  Future<Map<String, Object?>> kind(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT applicable_types, auto_attach, default_interval_days, '
          'default_category, exposure_intervals, updated_at '
          'FROM service_kinds WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.data;
  }

  test('v393 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(393));
    expect(AppDatabase.migrationVersions, contains(393));
    expect(AppDatabase.migrationStepCount(392), greaterThanOrEqualTo(1));
    // Reference-data rung: built-in kinds never sync, so the floor holds.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(393));
  });

  test('a fresh database seeds the inspection for BCDs and wings', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    expect(
      (await kind(db, 'bcd-inspection'))['applicable_types'],
      bcdWingTypes,
    );
  });

  test('an upgraded database widens the built-in kind to wings', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await kind(db, 'bcd-inspection');
    expect(row['applicable_types'], bcdWingTypes);
    // Only the type list moves; the kind's clock and flags are untouched.
    expect(row['auto_attach'], 1);
    expect(row['default_interval_days'], 365);
    expect(row['default_category'], 'inspection');
    expect(row['exposure_intervals'], '{}');
    expect(row['updated_at'], 5);
  });

  test('a custom kind keeps the types its diver chose', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect((await kind(db, 'custom-bcd'))['applicable_types'], '["bcd"]');
  });

  test('the backfill and the seed agree on the type list', () async {
    // The seed is INSERT OR IGNORE, so it cannot fix an existing row, and the
    // backfill runs from the v393 rung only. The two must name the same
    // types or a fresh install and an upgraded one would disagree.
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);

    expect(
      (await kind(upgraded, 'bcd-inspection'))['applicable_types'],
      (await kind(fresh, 'bcd-inspection'))['applicable_types'],
    );
  });

  test('the stored names resolve to the BCD and wing types', () async {
    // applicable_types holds EquipmentType names, and the repository skips a
    // name it cannot resolve, so a misspelt type would fail silently.
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final stored = (await kind(db, 'bcd-inspection'))['applicable_types'];
    final types = [
      for (final name in jsonDecode(stored! as String) as List<dynamic>)
        EquipmentType.values.byName(name as String),
    ];
    expect(types, [EquipmentType.bcd, EquipmentType.wing]);
  });
}
