import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:submersion/core/database/database.dart';

/// v210 gives dive_tanks.equipment_id the ON DELETE SET NULL action every
/// other nullable link to equipment already has. It was NO ACTION from the
/// initial schema, so once the transmitter registry started writing it,
/// deleting a linked gear item (locally or from a peer's tombstone) failed
/// with a foreign key error. SQLite cannot alter a constraint in place, so
/// the rung rebuilds the table from its own stored definition.

/// Deletes and tombstones look tanks up by equipment_id.
Future<bool> _hasEquipmentIndex(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name = 'idx_dive_tanks_equipment'",
      )
      .get();
  return rows.isNotEmpty;
}

Future<Map<String, String>> _onDelete(AppDatabase db) async {
  final rows = await db
      .customSelect("PRAGMA foreign_key_list('dive_tanks')")
      .get();
  return {
    for (final r in rows) r.read<String>('from'): r.read<String>('on_delete'),
  };
}

/// A dive_tanks table as an older database holds it: the equipment link
/// with no action, a v202-style regulator link that already sets null, an
/// index, and a child table that cascades from the tanks.
void _seedOldSchema(Database raw, {required int userVersion}) {
  // On, so the rung has to switch enforcement off itself: with it on, the
  // DROP inside a rebuild would cascade into every child row.
  raw.execute('PRAGMA foreign_keys = ON');
  raw.execute('PRAGMA user_version = $userVersion');
  raw.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
  raw.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
  raw.execute('''
    CREATE TABLE dive_tanks (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
      equipment_id TEXT REFERENCES equipment(id),
      volume REAL,
      tank_name TEXT
    )
  ''');
  raw.execute(
    'ALTER TABLE dive_tanks ADD COLUMN regulator_equipment_id TEXT '
    'REFERENCES equipment(id) ON DELETE SET NULL',
  );
  raw.execute('CREATE INDEX idx_dive_tanks_dive_id ON dive_tanks(dive_id)');
  raw.execute('''
    CREATE TABLE fk_probe_child (
      id TEXT NOT NULL PRIMARY KEY,
      tank_id TEXT NOT NULL REFERENCES dive_tanks(id) ON DELETE CASCADE
    )
  ''');
  raw.execute("INSERT INTO equipment VALUES ('cyl'), ('reg')");
  raw.execute("INSERT INTO dives VALUES ('d1')");
  raw.execute(
    "INSERT INTO dive_tanks VALUES ('t1', 'd1', 'cyl', 11.1, 'Back gas', "
    "'reg')",
  );
  raw.execute(
    "INSERT INTO dive_tanks VALUES ('t2', 'd1', NULL, 7.0, 'Deco', NULL)",
  );
  raw.execute("INSERT INTO fk_probe_child VALUES ('c1', 't1'), ('c2', 't2')");
  // The deletion log as it was before tombstones carried the delete's clock.
  raw.execute('''
    CREATE TABLE deletion_log (
      id TEXT NOT NULL PRIMARY KEY,
      entity_type TEXT NOT NULL,
      record_id TEXT NOT NULL,
      deleted_at INTEGER NOT NULL,
      hlc TEXT
    )
  ''');
  raw.execute(
    "INSERT INTO deletion_log VALUES ('x1', 'diveTanks', 't9', 5, 'h')",
  );
}

Future<void> _expectRebuilt(AppDatabase db) async {
  final actions = await _onDelete(db);
  expect(actions['equipment_id'], 'SET NULL');
  expect(actions['regulator_equipment_id'], 'SET NULL');
  expect(actions['dive_id'], 'CASCADE');

  final tanks = await db
      .customSelect(
        'SELECT id, dive_id, equipment_id, volume, tank_name, '
        'regulator_equipment_id FROM dive_tanks ORDER BY id',
      )
      .get();
  expect(tanks.map((r) => r.data).toList(), [
    {
      'id': 't1',
      'dive_id': 'd1',
      'equipment_id': 'cyl',
      'volume': 11.1,
      'tank_name': 'Back gas',
      'regulator_equipment_id': 'reg',
    },
    {
      'id': 't2',
      'dive_id': 'd1',
      'equipment_id': null,
      'volume': 7.0,
      'tank_name': 'Deco',
      'regulator_equipment_id': null,
    },
  ]);

  final children = await db
      .customSelect('SELECT id FROM fk_probe_child ORDER BY id')
      .get();
  expect(children.map((r) => r.read<String>('id')), [
    'c1',
    'c2',
  ], reason: 'the rebuild must not cascade into rows that hang off the tanks');

  final indexes = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND tbl_name = 'dive_tanks' AND name = 'idx_dive_tanks_dive_id'",
      )
      .get();
  expect(indexes, hasLength(1));

  expect(await _hasEquipmentIndex(db), isTrue);

  // The children's own clocks (v210): the rebuilt tanks carry one too.
  final tankCols = await db
      .customSelect("PRAGMA table_info('dive_tanks')")
      .get();
  expect(tankCols.map((c) => c.read<String>('name')), contains('hlc'));
  // And a tombstone's (v210), with the existing log kept and unclocked.
  final tombstones = await db
      .customSelect('SELECT record_id, hlc, origin_hlc FROM deletion_log')
      .get();
  expect(tombstones.map((r) => r.data).toList(), [
    {'record_id': 't9', 'hlc': 'h', 'origin_hlc': null},
  ]);

  // The child's reference still names the rebuilt table.
  final childLinks = await db
      .customSelect("PRAGMA foreign_key_list('fk_probe_child')")
      .get();
  expect(childLinks.single.read<String>('table'), 'dive_tanks');
}

void main() {
  test('v210 is the current schema version and is in the ladder', () {
    // Relaxed once v211 (issue #998's auto_tag_imports) landed on top; the
    // newest rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(210));
    expect(AppDatabase.migrationVersions, contains(210));
  });

  test('the sync compatibility floor is 210', () {
    // An older peer's code deletes an equipment row with no regard for
    // the linked cylinders, so under its NO ACTION link a tombstone from
    // this build fails there and the item lingers. Holding readers below
    // 210 until they update is what makes the tombstone apply.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('a fresh database creates the link with ON DELETE SET NULL', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect((await _onDelete(db))['equipment_id'], 'SET NULL');
    expect(await _hasEquipmentIndex(db), isTrue);

    // The point of the rung: deleting the linked item clears the link.
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('cyl', 'Blue AL80', 'tank', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, equipment_id) "
      "VALUES ('t1', 'd1', 'cyl')",
    );
    await db.customStatement("DELETE FROM equipment WHERE id = 'cyl'");
    final t1 = await db
        .customSelect("SELECT equipment_id FROM dive_tanks WHERE id = 't1'")
        .getSingle();
    expect(t1.read<String?>('equipment_id'), isNull);
  });

  test('upgrading from 209 rebuilds the table and keeps every row', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => _seedOldSchema(raw, userVersion: 209),
      ),
    );
    addTearDown(db.close);

    await _expectRebuilt(db);
  });

  test(
    'a database stranded at the current version is repaired on open',
    () async {
      // Reached the current version through a path that skipped the rung: the
      // beforeOpen backstop is its only way to the new action.
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) => _seedOldSchema(
            raw,
            userVersion: AppDatabase.currentSchemaVersion,
          ),
        ),
      );
      addTearDown(db.close);

      await _expectRebuilt(db);
    },
  );

  test('a link with an action the rung does not own is left alone', () async {
    // Only NO ACTION (or RESTRICT) is rewritten. Any other action stays as
    // it is rather than gaining a second ON DELETE clause.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 209');
          raw.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
          raw.execute('''
            CREATE TABLE dive_tanks (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              equipment_id TEXT REFERENCES equipment(id) ON DELETE CASCADE
            )
          ''');
          raw.execute("INSERT INTO dive_tanks VALUES ('t1', 'd1', NULL)");
        },
      ),
    );
    addTearDown(db.close);

    expect((await _onDelete(db))['equipment_id'], 'CASCADE');
    final stored = await db
        .customSelect("SELECT sql FROM sqlite_master WHERE name = 'dive_tanks'")
        .getSingle();
    final sql = stored.read<String>('sql');
    expect(
      sql,
      isNot(contains('ON DELETE SET NULL ON DELETE')),
      reason: 'not rebuilt with a second ON DELETE clause',
    );
    // A rebuilt table is renamed into place and stored as "dive_tanks".
    expect(sql, startsWith('CREATE TABLE dive_tanks ('), reason: 'untouched');
    final rows = await db.customSelect('SELECT id FROM dive_tanks').get();
    expect(rows, hasLength(1));
  });

  test('a dive_tanks without the equipment link is left alone', () async {
    // Partial-schema fixtures elsewhere build dive_tanks with a plain column
    // and no equipment table; the rung has nothing to change there.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 209');
          raw.execute('''
            CREATE TABLE dive_tanks (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              equipment_id TEXT
            )
          ''');
          raw.execute("INSERT INTO dive_tanks VALUES ('t1', 'd1', 'x')");
        },
      ),
    );
    addTearDown(db.close);

    expect((await _onDelete(db)).containsKey('equipment_id'), isFalse);
    final rows = await db.customSelect('SELECT id FROM dive_tanks').get();
    expect(rows, hasLength(1));
  });
}
