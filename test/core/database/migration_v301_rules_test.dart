import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v301 adds the logbook rules tables (#3513): rules, rule_runs and
/// rule_run_changes. Table-only rung, additive, floor unchanged.

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _indexes(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

const _ruleTables = {'rules', 'rule_runs', 'rule_run_changes'};
const _ruleIndexes = {
  'idx_rules_diver',
  'idx_rule_runs_diver',
  'idx_rule_run_changes_run',
};

void main() {
  test('v301 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 301);
    expect(AppDatabase.migrationVersions.last, 301);
    expect(AppDatabase.migrationStepCount(300), 1);
  });

  test('a fresh database has the three tables and their indexes', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    expect(await _tables(db), containsAll(_ruleTables));
    expect(await _indexes(db), containsAll(_ruleIndexes));
    expect(await _columns(db, 'rules'), {
      'id',
      'diver_id',
      'subject',
      'name',
      'enabled',
      'triggers',
      'condition_json',
      'actions_json',
      'sort_order',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(await _columns(db, 'rule_runs'), {
      'id',
      'diver_id',
      'trigger',
      'source_label',
      'device_label',
      'ran_at',
      'changed_count',
      'undone_at',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(await _columns(db, 'rule_run_changes'), {
      'id',
      'run_id',
      'subject',
      'target_id',
      'rule_id',
      'rule_name',
      'field',
      'before_json',
      'after_json',
      'sort_order',
      'created_at',
      'updated_at',
      'hlc',
    });
  });

  test('a database already at v301 without the tables gains them', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), containsAll(_ruleTables));
    expect(await _indexes(db), containsAll(_ruleIndexes));
  });

  test('deleting a run deletes its changes', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(
      "INSERT INTO rule_runs (id, trigger, ran_at, changed_count, created_at, "
      "updated_at) VALUES ('r', 'imported', 1, 1, 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO rule_run_changes (id, run_id, subject, target_id, '
      'rule_name, field, before_json, after_json, sort_order, created_at, '
      "updated_at) VALUES ('c', 'r', 'dives', 'd', 'Deep', 'diveTypes', "
      "'[]', '[\"deep\"]', 0, 1, 1)",
    );
    await db.customStatement("DELETE FROM rule_runs WHERE id = 'r'");
    final left = await db
        .customSelect('SELECT COUNT(*) AS n FROM rule_run_changes')
        .getSingle();
    expect(left.read<int>('n'), 0);
  });
}
