import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v207 gives the three composite-natural-key gear junctions an `updated_at`
/// (issue #1728). Without one, `_extractUpdatedAtMillis` returns null for
/// these rows, which collapses both of `_applyRemoteDeletions`' guards to
/// false and makes `_mergeEntity`'s revival branch unreachable -- so a lost
/// link is permanent. The rung backfills from the parent the junction rides.

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<int?> _updatedAt(AppDatabase db, String table, String sql) async {
  final rows = await db.customSelect(sql).get();
  return rows.single.read<int?>('updated_at');
}

const _junctions = [
  'dive_equipment',
  'equipment_set_items',
  'dive_plan_equipment',
];

void main() {
  test('v207 is in the ladder and shipped', () {
    // Relaxed as v200's own test asked, now that later rungs (v208, the
    // imported-file store, issue #478; v209, the nav_tracks table) are
    // newer. This one only claims its rung is still in the ladder.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(207));
    expect(AppDatabase.migrationVersions, contains(207));
  });

  test('a fresh database has updated_at on all three junctions', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (final table in _junctions) {
      expect(await _columns(db, table), contains('updated_at'), reason: table);
    }
  });

  test('an inserted link is stamped without the caller saying so', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final before = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'gear-1',
            name: 'Wing',
            type: 'bcd',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'dive-1',
            equipmentId: 'gear-1',
          ),
        );

    final row = await db.select(db.diveEquipment).getSingle();
    expect(
      row.updatedAt,
      isNotNull,
      reason:
          'a clientDefault stamps every insert site, so a future call '
          'site cannot silently reintroduce a clockless link',
    );
    expect(row.updatedAt, greaterThanOrEqualTo(before));
  });

  test('a parent stripped to its id is survivable, not fatal', () async {
    // beforeOpen re-asserts this rung on EVERY open, including against the
    // minimal old-schema fixtures other migration tests build and against
    // genuinely ancient databases. Selecting a column the parent does not
    // have aborts the open with a SQL logic error, so "nothing to backfill
    // from" must leave NULL rather than throw.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 206');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_equipment (
            dive_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (dive_id, equipment_id)
          )
        ''');
        rawDb.execute("INSERT INTO dives VALUES ('d1')");
        rawDb.execute("INSERT INTO dive_equipment VALUES ('d1', 'g1')");
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _columns(db, 'dive_equipment'), contains('updated_at'));
    expect(
      await _updatedAt(
        db,
        'dive_equipment',
        'SELECT updated_at FROM dive_equipment',
      ),
      isNull,
    );
  });

  test(
    'a stranded database gains the column, backfilled from its parent',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 206');
          rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute('''
          CREATE TABLE equipment_sets (
            id TEXT NOT NULL PRIMARY KEY,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute('''
          CREATE TABLE dive_plans (
            id TEXT NOT NULL PRIMARY KEY,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute('''
          CREATE TABLE dive_equipment (
            dive_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (dive_id, equipment_id)
          )
        ''');
          rawDb.execute('''
          CREATE TABLE equipment_set_items (
            set_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (set_id, equipment_id)
          )
        ''');
          rawDb.execute('''
          CREATE TABLE dive_plan_equipment (
            plan_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (plan_id, equipment_id)
          )
        ''');
          rawDb.execute("INSERT INTO dives VALUES ('d1', 7000)");
          rawDb.execute("INSERT INTO equipment_sets VALUES ('s1', 7100)");
          rawDb.execute("INSERT INTO dive_plans VALUES ('p1', 7200)");
          rawDb.execute("INSERT INTO dive_equipment VALUES ('d1', 'g1')");
          rawDb.execute("INSERT INTO equipment_set_items VALUES ('s1', 'g1')");
          rawDb.execute("INSERT INTO dive_plan_equipment VALUES ('p1', 'g1')");
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      for (final table in _junctions) {
        expect(
          await _columns(db, table),
          contains('updated_at'),
          reason: table,
        );
      }
      expect(
        await _updatedAt(
          db,
          'dive_equipment',
          'SELECT updated_at FROM dive_equipment',
        ),
        7000,
        reason:
            'the junction rides its dive, so the dive\'s updated_at is the '
            'age the link would have had',
      );
      expect(
        await _updatedAt(
          db,
          'equipment_set_items',
          'SELECT updated_at FROM equipment_set_items',
        ),
        7100,
      );
      expect(
        await _updatedAt(
          db,
          'dive_plan_equipment',
          'SELECT updated_at FROM dive_plan_equipment',
        ),
        7200,
      );
    },
  );
}
