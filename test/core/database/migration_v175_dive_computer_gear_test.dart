import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v175 adds `dive_computers.equipment_id`: the equipment row that represents a
/// registered computer as gear, so a downloaded dive lists the computer that
/// logged it alongside the rest of the diver's kit. Nullable with no default,
/// because a cleared value means the user deleted that gear item and it must
/// not come back.
const String _preV175DiveComputers = '''
  CREATE TABLE dive_computers (
    id TEXT NOT NULL PRIMARY KEY,
    diver_id TEXT,
    name TEXT NOT NULL,
    manufacturer TEXT,
    model TEXT,
    serial_number TEXT,
    dive_count INTEGER NOT NULL DEFAULT 0,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    notes TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';

NativeDatabase _dbAt168() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 168');
      rawDb.execute(_preV175DiveComputers);
      rawDb.execute(
        "INSERT INTO dive_computers (id, name, created_at, updated_at) "
        "VALUES ('c1', 'My Perdix', 1, 1)",
      );
    },
  );
}

void main() {
  test('v175 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(175));
    expect(AppDatabase.migrationVersions, contains(175));
  });

  test('a fresh database has dive_computers.equipment_id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_computers')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('equipment_id'));
  });

  test('the column is nullable and carries no default', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_computers')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'equipment_id',
    );
    // A non-null default would claim every registered computer already has a
    // gear item, and would resurrect one the user deleted.
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String?>('dflt_value'), isNull);
  });

  test('a database at v168 gains the column and keeps its rows', () async {
    final db = AppDatabase(_dbAt168());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT name, equipment_id FROM dive_computers WHERE id = 'c1'",
        )
        .getSingle();
    expect(row.read<String>('name'), 'My Perdix');
    expect(row.read<String?>('equipment_id'), isNull);
  });

  test('a database stranded at a parallel-branch v175 gains the column via '
      'beforeOpen', () async {
    // Stamped AT 175 but without the column: the onUpgrade block never runs,
    // so only the beforeOpen backstop can add it.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 175');
        rawDb.execute(_preV175DiveComputers);
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_computers')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('equipment_id'));
  });

  test('an UPGRADED database carries the FK, not just a fresh one', () async {
    // The bare `ALTER TABLE ... ADD COLUMN equipment_id TEXT` that an upgrade
    // runs has no REFERENCES clause, so onDelete: setNull would exist only on
    // databases created from scratch. That is backwards: existing users are
    // the ones who upgrade. Without the FK, deleting a gear item leaves
    // dive_computers.equipment_id pointing at a row that no longer exists, and
    // the linker then tries to insert a dive_equipment row against a missing
    // equipment id.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 168');
          rawDb.execute(_preV175DiveComputers);
          rawDb.execute('''
            CREATE TABLE equipment (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              brand TEXT,
              model TEXT,
              serial_number TEXT,
              status TEXT NOT NULL DEFAULT 'active',
              purchase_currency TEXT NOT NULL DEFAULT 'USD',
              notes TEXT NOT NULL DEFAULT '',
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute(
            "INSERT INTO equipment (id, name, type, created_at, updated_at) "
            "VALUES ('gear-1', 'gear-1', 'computer', 1, 1)",
          );
          rawDb.execute(
            "INSERT INTO dive_computers (id, name, created_at, updated_at) "
            "VALUES ('c1', 'My Perdix', 1, 1)",
          );
        },
      ),
    );
    addTearDown(db.close);

    // The declared FK is what carries the setNull behaviour.
    final fks = await db
        .customSelect("PRAGMA foreign_key_list('dive_computers')")
        .get();
    final toEquipment = fks.where(
      (r) => r.read<String>('table') == 'equipment',
    );
    expect(
      toEquipment,
      isNotEmpty,
      reason: 'upgraded dive_computers has no FK to equipment',
    );
    expect(toEquipment.first.read<String>('on_delete'), 'SET NULL');

    // And the behaviour itself: deleting the gear item clears the link rather
    // than stranding it.
    await db.customStatement(
      "UPDATE dive_computers SET equipment_id = 'gear-1' WHERE id = 'c1'",
    );
    await db.customStatement("DELETE FROM equipment WHERE id = 'gear-1'");

    final row = await db
        .customSelect("SELECT equipment_id FROM dive_computers WHERE id = 'c1'")
        .getSingle();
    expect(row.read<String?>('equipment_id'), isNull);
  });
}
