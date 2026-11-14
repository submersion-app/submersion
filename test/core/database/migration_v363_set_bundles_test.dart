import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v363 adds the three junction tables that let an equipment set carry
/// other sets, weight presets and cylinder configurations, and the body
/// composition columns on divers and their weight entries (#4525).
const _junctions = {
  'equipment_set_includes': 'included_set_id',
  'equipment_set_weight_presets': 'preset_id',
  'equipment_set_cylinder_configs': 'config_id',
};

Future<Set<String>> _tables(AppDatabase db) async => {
  for (final r
      in await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get())
    r.read<String>('name'),
};

Future<Set<String>> _columns(AppDatabase db, String table) async => {
  for (final r in await db.customSelect("PRAGMA table_info('$table')").get())
    r.read<String>('name'),
};

AppDatabase _fresh() =>
    AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));

Future<void> _seedParents(AppDatabase db) async {
  const t = 1700000000000;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('d1', 'Diver', $t, $t)",
  );
  for (final id in ['outer', 'inner']) {
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: id,
            name: id,
            diverId: const Value('d1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }
  await db
      .into(db.weightPresets)
      .insert(
        WeightPresetsCompanion.insert(
          id: 'p1',
          displayName: 'Belt',
          diverId: const Value('d1'),
          createdAt: t,
          updatedAt: t,
        ),
      );
  await db
      .into(db.cylinderConfigs)
      .insert(
        CylinderConfigsCompanion.insert(
          id: 'c1',
          name: 'AL80',
          diverId: const Value('d1'),
          createdAt: t,
          updatedAt: t,
        ),
      );
  await db
      .into(db.equipmentSetIncludes)
      .insert(
        EquipmentSetIncludesCompanion.insert(
          id: 'i1',
          setId: 'outer',
          includedSetId: 'inner',
          createdAt: t,
        ),
      );
  await db
      .into(db.equipmentSetWeightPresets)
      .insert(
        EquipmentSetWeightPresetsCompanion.insert(
          id: 'w1',
          setId: 'outer',
          presetId: 'p1',
          createdAt: t,
        ),
      );
  await db
      .into(db.equipmentSetCylinderConfigs)
      .insert(
        EquipmentSetCylinderConfigsCompanion.insert(
          id: 'k1',
          setId: 'outer',
          configId: 'c1',
          createdAt: t,
        ),
      );
}

Future<int> _count(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM $table')
      .getSingle();
  return row.read<int>('n');
}

void main() {
  test('v363 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(363));
    expect(AppDatabase.migrationVersions, contains(363));
    expect(AppDatabase.migrationStepCount(362), greaterThanOrEqualTo(1));
  });

  test('a fresh database has the three tables and the three columns', () async {
    final db = _fresh();
    addTearDown(db.close);
    final tables = await _tables(db);
    for (final entry in _junctions.entries) {
      expect(tables, contains(entry.key));
      expect(
        await _columns(db, entry.key),
        containsAll([
          'id',
          'set_id',
          entry.value,
          'sort_order',
          'created_at',
          'hlc',
        ]),
      );
    }
    expect(await _columns(db, 'divers'), containsAll(['sex', 'birth_year']));
    expect(
      await _columns(db, 'diver_weight_entries'),
      contains('body_fat_percent'),
    );
  });

  test('a database already at the current version gains them', () async {
    // Only the beforeOpen backstops can add them there (a restore or a
    // sync-adopt never runs onUpgrade). Build that database by opening a
    // real one, taking the v363 tables and columns back out, and reopening.
    final dir = await Directory.systemTemp.createTemp('v363_backstop');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'submersion.db'));

    final first = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    await first.customSelect('SELECT 1').get();
    for (final table in _junctions.keys) {
      await first.customStatement('DROP TABLE $table');
    }
    // The change-log triggers name every column, so they go first; the
    // reopen rebuilds them.
    final triggers = await first
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND tbl_name IN ('divers', 'diver_weight_entries')",
        )
        .get();
    for (final t in triggers) {
      await first.customStatement('DROP TRIGGER ${t.read<String>('name')}');
    }
    await first.customStatement('ALTER TABLE divers DROP COLUMN sex');
    await first.customStatement('ALTER TABLE divers DROP COLUMN birth_year');
    await first.customStatement(
      'ALTER TABLE diver_weight_entries DROP COLUMN body_fat_percent',
    );
    expect(await _tables(first), isNot(contains(_junctions.keys.first)));
    await first.close();

    final db = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    expect(await _tables(db), containsAll(_junctions.keys));
    expect(await _columns(db, 'divers'), containsAll(['sex', 'birth_year']));
    expect(
      await _columns(db, 'diver_weight_entries'),
      contains('body_fat_percent'),
    );
  });

  test('the pair index rejects the same preset twice in one set', () async {
    final db = _fresh();
    addTearDown(db.close);
    await _seedParents(db);
    expect(
      () => db
          .into(db.equipmentSetWeightPresets)
          .insert(
            EquipmentSetWeightPresetsCompanion.insert(
              id: 'w2',
              setId: 'outer',
              presetId: 'p1',
              createdAt: 1,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('deleting a set, preset or configuration removes its rows', () async {
    final db = _fresh();
    addTearDown(db.close);
    await _seedParents(db);

    await (db.delete(db.weightPresets)..where((p) => p.id.equals('p1'))).go();
    expect(await _count(db, 'equipment_set_weight_presets'), 0);

    await (db.delete(db.cylinderConfigs)..where((c) => c.id.equals('c1'))).go();
    expect(await _count(db, 'equipment_set_cylinder_configs'), 0);

    await (db.delete(
      db.equipmentSets,
    )..where((s) => s.id.equals('inner'))).go();
    expect(await _count(db, 'equipment_set_includes'), 0);
  });

  test('new rows default sort_order to zero', () async {
    final db = _fresh();
    addTearDown(db.close);
    await _seedParents(db);
    final row = await db.select(db.equipmentSetIncludes).getSingle();
    expect(row.sortOrder, 0);
    expect(row.hlc, isNull);
  });
}
