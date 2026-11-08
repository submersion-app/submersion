import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v345: twin set pairings (issue #4242). A new synced
/// `cylinder_pairings` table, `cylinder_fills.filled_together_id` tying the
/// two fills of a twin fill, and `dive_tanks.twin_passport_id` naming the
/// second cylinder of a twin set tank. No backfill.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, type TEXT NOT NULL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE cylinder_fills (id TEXT NOT NULL PRIMARY KEY, '
        'passport_id TEXT NOT NULL, equipment_id TEXT, '
        'filled_at INTEGER NOT NULL, o2_percent REAL NOT NULL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, passport_id TEXT)',
      );
      rawDb.execute(
        "INSERT INTO cylinder_fills VALUES ('f1', 'pp', NULL, 1, 32, 1, 1)",
      );
      rawDb.execute("INSERT INTO dive_tanks VALUES ('t1', 'd1', 'pp')");
    },
  );

  Future<List<String>> columnsOf(AppDatabase db, String table) async =>
      (await db.customSelect("PRAGMA table_info('$table')").get())
          .map((c) => c.read<String>('name'))
          .toList();

  test('v345 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(345));
    expect(AppDatabase.migrationVersions, contains(345));
    expect(
      AppDatabase.migrationStepCount(344),
      AppDatabase.migrationStepCount(345) + 1,
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(345));
  });

  test('upgrading from v344 creates cylinder_pairings', () async {
    final db = AppDatabase(dbAt(344));
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'cylinder_pairings'),
      containsAll(<String>[
        'id',
        'cylinder_a_id',
        'cylinder_b_id',
        'paired_on',
        'unpaired_on',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(await db.select(db.cylinderPairings).get(), isEmpty);
  });

  test('existing fills and tanks gain empty twin columns', () async {
    final db = AppDatabase(dbAt(344));
    addTearDown(db.close);
    final fill = await db
        .customSelect('SELECT filled_together_id FROM cylinder_fills')
        .getSingle();
    expect(fill.read<String?>('filled_together_id'), isNull);
    final tank = await db
        .customSelect('SELECT passport_id, twin_passport_id FROM dive_tanks')
        .getSingle();
    expect(tank.read<String>('passport_id'), 'pp');
    expect(tank.read<String?>('twin_passport_id'), isNull);
  });

  test('both cylinders of a pairing cascade from equipment', () async {
    final db = AppDatabase(dbAt(344));
    addTearDown(db.close);
    final keys = await db
        .customSelect("PRAGMA foreign_key_list('cylinder_pairings')")
        .get();
    for (final column in const ['cylinder_a_id', 'cylinder_b_id']) {
      final key = keys.singleWhere((k) => k.read<String>('from') == column);
      expect(key.read<String>('table'), 'equipment');
      expect(key.read<String>('on_delete'), 'CASCADE');
    }
  });

  test('the twin set indexes exist after open', () async {
    final db = AppDatabase(dbAt(344));
    addTearDown(db.close);
    final names =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(
      names,
      containsAll(<String>[
        'idx_cylinder_pairings_a',
        'idx_cylinder_pairings_b',
        'idx_cylinder_fills_together',
        'idx_dive_tanks_twin_passport_id',
      ]),
    );
  });

  test('asserting the schema twice is harmless', () async {
    final db = AppDatabase(dbAt(344));
    addTearDown(db.close);
    await db.assertTwinSetSchemaForTest();
    await db.assertTwinSetSchemaForTest();
    expect(await columnsOf(db, 'dive_tanks'), contains('twin_passport_id'));
  });
}
