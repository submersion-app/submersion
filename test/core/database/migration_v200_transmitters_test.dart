import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v200 adds the transmitter registry (issue #1365) and the parsed-tank
/// source index on dive_tanks (issue #1314).

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

void main() {
  test('v200 is in the ladder and shipped', () {
    // Relaxed as this rung's own comment asked, now that later rungs (v201,
    // the cell linearity link, and v202, equipment condition intelligence)
    // are newer. This one only claims its rung is still in the ladder.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(200));
    expect(AppDatabase.migrationVersions, contains(200));
  });

  test(
    'a fresh database has the transmitters table and the source index',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await _tables(db), contains('transmitters'));
      expect(
        await _columns(db, 'transmitters'),
        containsAll([
          'id',
          'diver_id',
          'transmitter_serial',
          'dive_computer_id',
          'channel_index',
          'label',
          'tank_role',
          'volume_l',
          'working_pressure_bar',
          'tank_material',
          'preset_name',
          'equipment_id',
          'created_at',
          'updated_at',
          'hlc',
        ]),
      );
      expect(await _columns(db, 'dive_tanks'), contains('source_tank_index'));
    },
  );

  test('a database stranded before v200 gains both', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 199');
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tank_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('transmitters'));
    expect(await _columns(db, 'dive_tanks'), contains('source_tank_index'));
  });

  test('deleting the linked gear nulls equipment_id, not the entry', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('g1', 'AL80', 'tank', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO transmitters (id, label, tank_role, equipment_id, "
      "created_at, updated_at) VALUES ('t1', 'T1', 'backGas', 'g1', 1, 1)",
    );

    await db.customStatement("DELETE FROM equipment WHERE id = 'g1'");

    final row = await db
        .customSelect("SELECT equipment_id FROM transmitters WHERE id = 't1'")
        .getSingle();
    expect(row.read<String?>('equipment_id'), isNull);
  });
}
