import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v124 creates equipment_attributes and copies legacy columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 112');
        rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE equipment (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            size TEXT,
            thickness TEXT,
            buoyancy_kg REAL,
            weight_kg REAL,
            status TEXT NOT NULL DEFAULT 'active',
            notes TEXT NOT NULL DEFAULT '',
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute('''
          INSERT INTO equipment
            (id, name, type, size, thickness, buoyancy_kg, weight_kg,
             created_at, updated_at)
          VALUES
            ('eq1', 'Suit', 'wetsuit', 'L', '5/4/3', 2.5, 3.0, 1000, 2000),
            ('eq2', 'Old suit', 'wetsuit', NULL, '6mm', NULL, NULL, 1000, 2000),
            ('eq3', 'Odd', 'wetsuit', NULL, 'thin', NULL, NULL, 1000, 2000),
            ('eq4', 'Reg', 'regulator', NULL, NULL, NULL, NULL, 1000, 2000)
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    Future<Map<String, dynamic>?> attr(String eqId, String key) async {
      final rows = await db
          .customSelect(
            'SELECT * FROM equipment_attributes '
            'WHERE equipment_id = ? AND attr_key = ?',
            variables: [Variable<String>(eqId), Variable<String>(key)],
          )
          .get();
      return rows.isEmpty ? null : rows.single.data;
    }

    // eq1: all four legacy columns copied, deterministic ids, parent timestamps.
    final size = await attr('eq1', 'size');
    expect(size, isNotNull);
    expect(size!['id'], 'attr_eq1_size');
    expect(size['value_text'], 'L');
    expect(size['created_at'], 1000);
    expect(size['updated_at'], 2000);
    expect(size['hlc'], isNull);

    final thick = await attr('eq1', 'thickness_mm');
    expect(thick!['value_text'], '5/4/3');
    expect(thick['value_num'], 5.0);

    expect((await attr('eq1', 'buoyancy_kg'))!['value_num'], 2.5);
    expect((await attr('eq1', 'dry_weight_kg'))!['value_num'], 3.0);

    // eq2: "6mm" parses to 6.0.
    final thick2 = await attr('eq2', 'thickness_mm');
    expect(thick2!['value_num'], 6.0);
    expect(thick2['value_text'], '6mm');

    // eq3: unparseable thickness keeps text, null number.
    final thick3 = await attr('eq3', 'thickness_mm');
    expect(thick3!['value_num'], isNull);
    expect(thick3['value_text'], 'thin');

    // eq4: no legacy values -> no rows.
    expect(await attr('eq4', 'size'), isNull);
    expect(await attr('eq4', 'thickness_mm'), isNull);

    // Indexes exist.
    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name LIKE 'idx_equipment_attributes%'",
        )
        .get();
    final names = indexes.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('idx_equipment_attributes_equipment_id'));
    expect(names, contains('idx_equipment_attributes_key_num'));
  });

  test(
    'reopen (beforeOpen backstop) does not resurrect cleared values',
    () async {
      final dir = await Directory.systemTemp.createTemp('subm_v124_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/test.db';

      // Seed a pre-v124 file-backed schema directly with sqlite3 (a setup
      // callback would re-run on every open and reset user_version).
      final raw = sqlite3.open(path);
      raw.execute('PRAGMA user_version = 112');
      raw.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      raw.execute('''
        CREATE TABLE equipment (
          id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
          type TEXT NOT NULL, size TEXT, thickness TEXT,
          buoyancy_kg REAL, weight_kg REAL,
          status TEXT NOT NULL DEFAULT 'active',
          notes TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT
        )
      ''');
      raw.execute(
        "INSERT INTO equipment (id, name, type, size, created_at, updated_at) "
        "VALUES ('eq1', 'Suit', 'wetsuit', 'L', 1000, 2000)",
      );
      raw.dispose();

      // First open runs the v124 migration and copies size -> attribute row.
      final db1 = AppDatabase(NativeDatabase(File(path)));
      final migrated = await db1
          .customSelect(
            "SELECT id FROM equipment_attributes WHERE id = 'attr_eq1_size'",
          )
          .get();
      expect(migrated, hasLength(1));

      // User clears the value, then the app restarts.
      await db1.customStatement(
        "DELETE FROM equipment_attributes WHERE id = 'attr_eq1_size'",
      );
      await db1.close();

      // Second open: onUpgrade is skipped (user_version is already 124); the
      // beforeOpen backstop must assert schema only and NOT re-copy data.
      final db2 = AppDatabase(NativeDatabase(File(path)));
      addTearDown(() => db2.close());
      final rows = await db2
          .customSelect(
            "SELECT id FROM equipment_attributes WHERE id = 'attr_eq1_size'",
          )
          .get();
      expect(rows, isEmpty);
    },
  );

  test('v124 equipment_attributes migration is in the ladder', () {
    // Membership, not equality: v124 was renumbered from v115/v123 as main advanced
    // past it at merge time (see schema-version ladder). The exact-latest
    // tripwire is not pinned here so later branches can land on top.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(124));
    expect(AppDatabase.migrationVersions, contains(124));
  });

  test('fresh database exposes equipment_attributes via Drift', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    expect(await db.select(db.equipmentAttributes).get(), isEmpty);
  });
}
