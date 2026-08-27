import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

// Minimal v103-shape fixture: only the tables/columns the v104 migration and
// its beforeOpen backstop touch.
NativeDatabase _v103Db({int? userVersion}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = ${userVersion ?? 103}');
      rawDb.execute('''CREATE TABLE divers (id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL)''');
      rawDb.execute('''CREATE TABLE dives (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, dive_date_time INTEGER NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          diver_role TEXT, hlc TEXT)''');
      rawDb.execute('''CREATE TABLE equipment (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, name TEXT NOT NULL, type TEXT NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          hlc TEXT)''');
      rawDb.execute('''CREATE TABLE dive_plans (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, name TEXT NOT NULL, gf_low INTEGER NOT NULL,
          gf_high INTEGER NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL, hlc TEXT)''');
      rawDb.execute(
        "INSERT INTO dives (id, dive_date_time, created_at, "
        "updated_at) VALUES ('d1', 1000, 1000, 1000)",
      );
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('fresh database has v104 tables and columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['diver_weight_entries', 'dive_plan_equipment']));
    expect(
      await _columns(db, 'dives'),
      containsAll(['weighting_feedback', 'weighting_feedback_kg']),
    );
    expect(
      await _columns(db, 'equipment'),
      containsAll(['buoyancy_kg', 'weight_kg']),
    );
    expect(
      await _columns(db, 'dive_plans'),
      containsAll(['planned_weight_kg', 'planned_weight_placement']),
    );
  });

  test(
    'real onUpgrade from v103 creates tables/columns preserving rows',
    () async {
      final db = AppDatabase(_v103Db());
      addTearDown(db.close);
      expect(await _columns(db, 'dives'), contains('weighting_feedback'));
      expect(await _columns(db, 'equipment'), contains('buoyancy_kg'));
      expect(await _columns(db, 'dive_plans'), contains('planned_weight_kg'));
      final rows = await db.customSelect('SELECT id FROM dives').get();
      expect(rows.single.read<String>('id'), 'd1');
      final idx = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='idx_diver_weight_entries_diver_id'",
          )
          .get();
      expect(idx, isNotEmpty);
    },
  );

  test('beforeOpen backstop heals a DB at currentSchemaVersion missing '
      'the v104 objects', () async {
    final db = AppDatabase(
      _v103Db(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(await _columns(db, 'dives'), contains('weighting_feedback'));
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='diver_weight_entries'",
        )
        .get();
    expect(tables, isNotEmpty);
  });

  test('version ladder includes 104', () {
    // Exact-latest tripwire moved to the newest version's migration test
    // (v105) when the heading migration landed on top of this one.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(104));
    expect(AppDatabase.migrationVersions, contains(104));
  });
}
