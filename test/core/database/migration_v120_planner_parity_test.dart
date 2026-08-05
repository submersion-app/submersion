import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

// Minimal pre-v120 fixture: the three plan tables without the v120 columns,
// stamped at v112 (this branch's prior version).
NativeDatabase _preV120Db({int? userVersion}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = ${userVersion ?? 112}');
      rawDb.execute('''CREATE TABLE divers (id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL)''');
      rawDb.execute('''CREATE TABLE dive_plans (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, name TEXT NOT NULL, mode TEXT, gf_low INTEGER NOT NULL,
          gf_high INTEGER NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL, hlc TEXT)''');
      rawDb.execute('''CREATE TABLE dive_plan_tanks (
          id TEXT PRIMARY KEY NOT NULL, plan_id TEXT NOT NULL,
          gas_o2 REAL NOT NULL DEFAULT 21.0, gas_he REAL NOT NULL DEFAULT 0.0,
          role TEXT NOT NULL DEFAULT 'backGas', sort_order INTEGER NOT NULL
          DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          hlc TEXT)''');
      rawDb.execute(
        '''CREATE TABLE dive_plan_segments (
          id TEXT PRIMARY KEY NOT NULL, plan_id TEXT NOT NULL, type TEXT NOT
          NULL, start_depth REAL NOT NULL, end_depth REAL NOT NULL,
          duration_seconds INTEGER NOT NULL, tank_id TEXT NOT NULL,
          gas_o2 REAL NOT NULL, gas_he REAL NOT NULL, rate REAL,
          switch_to_tank_id TEXT, sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)''',
      );
      rawDb.execute(
        "INSERT INTO dive_plans (id, name, gf_low, gf_high, created_at, "
        "updated_at) VALUES ('p1', 'Old plan', 30, 70, 1000, 1000)",
      );
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('fresh database has the v120 planner columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _columns(db, 'dive_plans'), contains('start_date_time'));
    expect(
      await _columns(db, 'dive_plan_segments'),
      containsAll(['setpoint_bar', 'dive_mode_override']),
    );
    expect(
      await _columns(db, 'dive_plan_tanks'),
      contains('deco_switch_depth'),
    );
  });

  test('onUpgrade from v112 adds the columns, preserving rows', () async {
    final db = AppDatabase(_preV120Db());
    addTearDown(db.close);
    expect(await _columns(db, 'dive_plans'), contains('start_date_time'));
    expect(
      await _columns(db, 'dive_plan_segments'),
      containsAll(['setpoint_bar', 'dive_mode_override']),
    );
    expect(
      await _columns(db, 'dive_plan_tanks'),
      contains('deco_switch_depth'),
    );
    final rows = await db.customSelect('SELECT id FROM dive_plans').get();
    expect(rows.single.read<String>('id'), 'p1');
  });

  test('beforeOpen backstop heals a DB stamped at currentSchemaVersion but '
      'missing the v120 columns', () async {
    final db = AppDatabase(
      _preV120Db(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(await _columns(db, 'dive_plans'), contains('start_date_time'));
    expect(await _columns(db, 'dive_plan_segments'), contains('setpoint_bar'));
  });

  test('version ladder includes 120', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(120));
    expect(AppDatabase.migrationVersions, contains(120));
  });
}
