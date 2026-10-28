import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v323: diver_settings gains each list's saved sort and grouping,
/// Equipment's arrangement, and the clock they sync under (issue #3748).
/// Every value starts empty, which reads as the list's starting order, so no
/// diver's library changes on upgrade. Only the clock is filled, from the
/// row clock, so the first unrelated settings save after the upgrade cannot
/// hand this device's untouched arrangement a brand-new clock.
void main() {
  const valueColumns = [
    'dive_list_sort',
    'dive_plan_list_sort',
    'trip_list_sort',
    'course_list_sort',
    'buddy_list_sort',
    'dive_center_list_sort',
    'site_list_sort',
    'certification_list_sort',
    'equipment_list_sort',
    'site_list_group_by',
    'certification_list_group_by',
    'equipment_arrangement',
    'equipment_group_by_location',
  ];

  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL, hlc TEXT)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id, hlc) "
        "VALUES ('s1', 'd1', '000001700000000:000001:node-a')",
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id, hlc) "
        "VALUES ('s2', 'd2', NULL)",
      );
    },
  );

  test('v323 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(323));
    expect(AppDatabase.migrationVersions, contains(323));
    expect(
      AppDatabase.migrationStepCount(322),
      AppDatabase.migrationStepCount(323) + 1,
    );
  });

  test('the columns are additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(323));
  });

  test(
    'v322 database upgrades with every column present and null values',
    () async {
      final db = AppDatabase(dbAt(322));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            "SELECT ${valueColumns.join(', ')} FROM diver_settings "
            "WHERE id = 's1'",
          )
          .getSingle();
      for (final column in valueColumns) {
        expect(row.data[column], isNull, reason: column);
      }
    },
  );

  test('list_arrangement_hlc copies the row hlc', () async {
    final db = AppDatabase(dbAt(322));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          "SELECT list_arrangement_hlc FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(
      row.read<String?>('list_arrangement_hlc'),
      '000001700000000:000001:node-a',
    );
  });

  test('a row with no hlc keeps a null group clock', () async {
    final db = AppDatabase(dbAt(322));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          "SELECT list_arrangement_hlc FROM diver_settings WHERE id = 's2'",
        )
        .getSingle();
    expect(row.read<String?>('list_arrangement_hlc'), isNull);
  });

  test('the clock backfill runs once, not on every open', () async {
    // A null arrangement clock on a row that has one already means "never
    // arranged" (SyncFactGroup.nullClockIsUnset); a later open must not
    // hand it the row clock of an unrelated save.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 323');
          rawDb.execute(
            'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
            'diver_id TEXT NOT NULL, hlc TEXT, list_arrangement_hlc TEXT)',
          );
          rawDb.execute(
            "INSERT INTO diver_settings (id, diver_id, hlc) "
            "VALUES ('s1', 'd1', '000001700000000:000001:node-a')",
          );
        },
      ),
    );
    addTearDown(db.close);
    final row = await db
        .customSelect(
          "SELECT list_arrangement_hlc FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<String?>('list_arrangement_hlc'), isNull);
  });

  test('beforeOpen heals a database already at v323 that lacks them', () async {
    final db = AppDatabase(dbAt(323));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(columns, containsAll([...valueColumns, 'list_arrangement_hlc']));
  });
}
