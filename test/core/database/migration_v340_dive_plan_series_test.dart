import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v340: dive_plan_series, a saved repetitive dive series, and the
/// dive_plans / dive_plan_tanks columns that place a plan in one (issue
/// #3565). No backfill: every existing plan is a one-dive series, and every
/// existing plan tank keeps its own start pressure.
void main() {
  NativeDatabase dbAt(
    int version, {
    bool withSeries = false,
  }) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL)',
      );
      rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      if (withSeries) {
        rawDb.execute(
          'CREATE TABLE dive_plan_series ('
          'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
          'name TEXT NOT NULL, followed_dive_id TEXT, '
          'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
          'hlc TEXT)',
        );
      }
      rawDb.execute(
        'CREATE TABLE dive_plans ('
        'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
        'name TEXT NOT NULL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'hlc TEXT${withSeries ? ', series_id TEXT, series_index INTEGER, '
                  'dive_name TEXT' : ''})',
      );
      rawDb.execute(
        'CREATE TABLE dive_plan_tanks ('
        'id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL, '
        'start_pressure REAL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'hlc TEXT${withSeries ? ', source_tank_id TEXT, '
                  'start_pressure_pinned INTEGER NOT NULL DEFAULT 0' : ''})',
      );
      rawDb.execute(
        'INSERT INTO dive_plans (id, name, created_at, updated_at) '
        "VALUES ('plan', 'Morning dive', 1, 1)",
      );
      rawDb.execute(
        'INSERT INTO dive_plan_tanks '
        '(id, plan_id, start_pressure, created_at, updated_at) '
        "VALUES ('tank', 'plan', 200.0, 1, 1)",
      );
    },
  );

  Future<List<String>> columnsOf(AppDatabase db, String table) async =>
      (await db.customSelect("PRAGMA table_info('$table')").get())
          .map((c) => c.read<String>('name'))
          .toList();

  test('v340 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(340));
    expect(AppDatabase.migrationVersions, contains(340));
    expect(
      AppDatabase.migrationStepCount(339),
      AppDatabase.migrationStepCount(340) + 1,
    );
  });

  test('the new table and columns are additive and kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(340));
  });

  test('upgrading from v339 creates dive_plan_series', () async {
    final db = AppDatabase(dbAt(339));
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'dive_plan_series'),
      containsAll(<String>[
        'id',
        'diver_id',
        'name',
        'followed_dive_id',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await columnsOf(db, 'dive_plan_series'),
      isNot(contains('shared_settings_json')),
    );
    expect(await db.select(db.divePlanSeries).get(), isEmpty);
  });

  test('every existing plan is a one-dive series, tanks unpinned', () async {
    final db = AppDatabase(dbAt(339));
    addTearDown(db.close);
    final plan = await db
        .customSelect(
          'SELECT series_id, series_index, dive_name FROM dive_plans',
        )
        .getSingle();
    expect(plan.read<String?>('series_id'), isNull);
    expect(plan.read<int?>('series_index'), isNull);
    expect(plan.read<String?>('dive_name'), isNull);

    final tank = await db
        .customSelect(
          'SELECT start_pressure, source_tank_id, start_pressure_pinned '
          'FROM dive_plan_tanks',
        )
        .getSingle();
    expect(tank.read<double>('start_pressure'), 200.0);
    expect(tank.read<String?>('source_tank_id'), isNull);
    expect(tank.read<int>('start_pressure_pinned'), 0);
  });

  test(
    'a plan references its series; a source tank references nothing',
    () async {
      final db = AppDatabase(dbAt(339));
      addTearDown(db.close);
      final planKeys = await db
          .customSelect("PRAGMA foreign_key_list('dive_plans')")
          .get();
      final seriesKey = planKeys.singleWhere(
        (k) => k.read<String>('from') == 'series_id',
      );
      expect(seriesKey.read<String>('table'), 'dive_plan_series');

      final tankKeys = await db
          .customSelect("PRAGMA foreign_key_list('dive_plan_tanks')")
          .get();
      expect(
        tankKeys.where((k) => k.read<String>('from') == 'source_tank_id'),
        isEmpty,
      );

      final seriesKeys = await db
          .customSelect("PRAGMA foreign_key_list('dive_plan_series')")
          .get();
      final byColumn = {
        for (final k in seriesKeys)
          k.read<String>('from'): k.read<String>('table'),
      };
      expect(byColumn['diver_id'], 'divers');
      expect(byColumn['followed_dive_id'], 'dives');
    },
  );

  test('plans are indexed by series', () async {
    final db = AppDatabase(dbAt(339));
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_dive_plans_series_id'",
        )
        .get();
    expect(rows, hasLength(1));
  });

  test('a database already carrying the schema is left alone', () async {
    final db = AppDatabase(dbAt(339, withSeries: true));
    addTearDown(db.close);
    final planColumns = await columnsOf(db, 'dive_plans');
    expect(planColumns.where((n) => n == 'series_id'), hasLength(1));
    expect(planColumns.where((n) => n == 'dive_name'), hasLength(1));
    final tankColumns = await columnsOf(db, 'dive_plan_tanks');
    expect(tankColumns.where((n) => n == 'source_tank_id'), hasLength(1));
  });

  test('the backstop restores the table and columns at v340', () async {
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_plan_series'), contains('hlc'));
    expect(
      await columnsOf(db, 'dive_plans'),
      containsAll(<String>['series_id', 'series_index', 'dive_name']),
    );
    expect(
      await columnsOf(db, 'dive_plan_tanks'),
      containsAll(<String>['source_tank_id', 'start_pressure_pinned']),
    );
  });
}
