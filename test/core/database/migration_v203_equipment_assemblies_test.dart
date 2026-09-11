import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v203 adds the equipment_components assembly template and the two
/// provenance columns on each gear junction (issue #1487). Additive, no
/// backfill.

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// `from>table:on_delete` for every foreign key on [table].
Future<Set<String>> _foreignKeys(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA foreign_key_list('$table')").get();
  return rows
      .map(
        (r) =>
            '${r.read<String>('from')}>${r.read<String>('table')}:'
            '${r.read<String>('on_delete')}',
      )
      .toSet();
}

void main() {
  test('v203 is in the ladder and shipped', () {
    // Renumbered twice: the cell linearity link took 201 and condition
    // intelligence took 202 while this branch was open.
    // Relaxed as this rung's own convention asks, now that v204 (dive list
    // trip grouping) sits on top; the newest rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(203));
    expect(AppDatabase.migrationVersions, contains(203));
  });

  test(
    'a fresh database has the components table and both column pairs',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await _tables(db), contains('equipment_components'));
      expect(
        await _columns(db, 'equipment_components'),
        containsAll([
          'id',
          'parent_equipment_id',
          'component_equipment_id',
          'role',
          'sort_order',
          'created_at',
          'updated_at',
          'hlc',
        ]),
      );
      for (final table in ['dive_equipment', 'dive_plan_equipment']) {
        expect(
          await _columns(db, table),
          containsAll(['via_equipment_id', 'via_set_id']),
          reason: table,
        );
        expect(
          await _foreignKeys(db, table),
          containsAll([
            'via_equipment_id>equipment:SET NULL',
            'via_set_id>equipment_sets:SET NULL',
          ]),
          reason: table,
        );
      }
    },
  );

  test('a database stranded before v203 gains the table and columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 202');
        // The helper adds each column only once its parent table exists,
        // so the fixture carries both parents.
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE equipment_sets (id TEXT NOT NULL PRIMARY KEY)',
        );
        rawDb.execute('''
          CREATE TABLE dive_equipment (
            dive_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (dive_id, equipment_id)
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_plan_equipment (
            plan_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (plan_id, equipment_id)
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('equipment_components'));
    for (final table in ['dive_equipment', 'dive_plan_equipment']) {
      expect(
        await _columns(db, table),
        containsAll(['via_equipment_id', 'via_set_id']),
        reason: table,
      );
    }
  });

  test('deleting either end of a component row cascades it away', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (final id in ['e1', 'e2', 'e3']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await db
        .into(db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion.insert(
            id: 'c1',
            parentEquipmentId: 'e1',
            componentEquipmentId: 'e2',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion.insert(
            id: 'c2',
            parentEquipmentId: 'e1',
            componentEquipmentId: 'e3',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    await (db.delete(db.equipment)..where((t) => t.id.equals('e3'))).go();
    var rows = await db.select(db.equipmentComponents).get();
    expect(rows.map((r) => r.id), ['c1']);

    await (db.delete(db.equipment)..where((t) => t.id.equals('e1'))).go();
    rows = await db.select(db.equipmentComponents).get();
    expect(rows, isEmpty);
  });

  test('the same pair cannot be inserted twice', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (final id in ['e1', 'e2']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'hose',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final row = EquipmentComponentsCompanion.insert(
      id: 'c1',
      parentEquipmentId: 'e1',
      componentEquipmentId: 'e2',
      createdAt: 1,
      updatedAt: 1,
    );
    await db.into(db.equipmentComponents).insert(row);
    expect(
      () => db
          .into(db.equipmentComponents)
          .insert(row.copyWith(id: const Value('c2'))),
      throwsA(anything),
    );
  });
}
