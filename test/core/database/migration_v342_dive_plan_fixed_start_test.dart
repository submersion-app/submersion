import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v342: dive_plans.fixed_start, whether a planned dive's start was
/// set by the diver rather than following from its surface interval (issue
/// #3565, phase 2). Defaulted false with no backfill: every saved dive keeps
/// its interval leading.
void main() {
  NativeDatabase dbAt(int version, {bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE dive_plans ('
            'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
            'name TEXT NOT NULL, start_date_time INTEGER, '
            'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
            'hlc TEXT, series_id TEXT, series_index INTEGER, '
            'dive_name TEXT'
            '${withColumn ? ', fixed_start INTEGER NOT NULL DEFAULT 0' : ''})',
          );
          rawDb.execute(
            'INSERT INTO dive_plans '
            '(id, name, start_date_time, created_at, updated_at) '
            "VALUES ('plan', 'Morning dive', 1762160400, 1, 1)",
          );
        },
      );

  Future<List<String>> columnsOf(AppDatabase db, String table) async =>
      (await db.customSelect("PRAGMA table_info('$table')").get())
          .map((c) => c.read<String>('name'))
          .toList();

  test('v342 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(342));
    expect(AppDatabase.migrationVersions, contains(342));
    expect(
      AppDatabase.migrationStepCount(341),
      AppDatabase.migrationStepCount(342) + 1,
    );
  });

  test('the new column is additive and kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(342));
  });

  test('upgrading from v341 leaves every saved start following', () async {
    final db = AppDatabase(dbAt(341));
    addTearDown(db.close);
    final plan = await db
        .customSelect('SELECT start_date_time, fixed_start FROM dive_plans')
        .getSingle();
    expect(plan.read<int>('start_date_time'), 1762160400);
    expect(plan.read<int>('fixed_start'), 0);
  });

  test('a database already carrying the column is left alone', () async {
    final db = AppDatabase(dbAt(341, withColumn: true));
    addTearDown(db.close);
    final columns = await columnsOf(db, 'dive_plans');
    expect(columns.where((n) => n == 'fixed_start'), hasLength(1));
  });

  test('the backstop restores the column at the current version', () async {
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_plans'), contains('fixed_start'));
  });
}
