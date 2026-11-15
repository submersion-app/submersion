import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/cylinder_volume_repair.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v368 (issue #4534): a cylinder volume an imperial diver typed in
/// cubic feet was stored as that many cubic feet of WATER, so an AL80 typed
/// as 77.4 became about 2192 L. The rung reads the stored litres back as the
/// figure typed and stores it as rated gas capacity at the item's working
/// pressure (200 bar assumed without one). Nothing is stamped.
void main() {
  NativeDatabase dbAt367({int version = 367}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, type TEXT NOT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE equipment_attributes (id TEXT NOT NULL PRIMARY KEY, '
        'equipment_id TEXT NOT NULL, attr_key TEXT NOT NULL, '
        'is_custom INTEGER NOT NULL DEFAULT 0, value_text TEXT, '
        'value_num REAL, sort_order INTEGER NOT NULL DEFAULT 0, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'hlc TEXT)',
      );
      void item(String id, String type) => rawDb.execute(
        "INSERT INTO equipment (id, name, type) VALUES ('$id', '$id', "
        "'$type')",
      );
      void attr(String item, String key, double value) => rawDb.execute(
        'INSERT INTO equipment_attributes (id, equipment_id, attr_key, '
        "value_num, created_at, updated_at, hlc) VALUES ('${item}_$key', "
        "'$item', '$key', $value, 1, 7, 'h1')",
      );
      item('al80', 'tank');
      attr('al80', 'volume_l', 77.4 / 0.0353147);
      attr('al80', 'working_pressure_bar', 206.843);
      item('bare', 'tank');
      attr('bare', 'volume_l', 80 / 0.0353147);
      item('twelve', 'tank');
      attr('twelve', 'volume_l', 12);
      item('bank', 'tank');
      attr('bank', 'volume_l', 50);
      item('vest', 'bcd');
      attr('vest', 'volume_l', 200);
    },
  );

  Future<double?> litres(AppDatabase db, String item) async =>
      (await db
              .customSelect(
                'SELECT value_num FROM equipment_attributes '
                "WHERE id = '${item}_volume_l'",
              )
              .getSingle())
          .read<double?>('value_num');

  test('v368 rewrites cylinder volumes saved as water cubic feet', () async {
    final db = AppDatabase(dbAt367());
    addTearDown(db.close);

    expect(await litres(db, 'al80'), 11.1);
    expect(await litres(db, 'bare'), closeTo(80 * 28.3168 / 200, 0.001));
  });

  test('real cylinder sizes and other items are left alone', () async {
    final db = AppDatabase(dbAt367());
    addTearDown(db.close);

    expect(await litres(db, 'twelve'), 12);
    expect(await litres(db, 'bank'), 50);
    expect(await litres(db, 'vest'), 200);
  });

  test('the repair stamps nothing and a second run changes nothing', () async {
    final db = AppDatabase(dbAt367());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT updated_at, hlc FROM equipment_attributes '
          "WHERE id = 'al80_volume_l'",
        )
        .getSingle();
    expect(row.read<int>('updated_at'), 7);
    expect(row.read<String>('hlc'), 'h1');
    expect(await repairCylinderVolumeCubicFeet(db), 0);
  });

  test('a volume saved with a unit since v368 is never repaired', () async {
    final db = AppDatabase(dbAt367());
    addTearDown(db.close);
    await db.customStatement(
      "UPDATE equipment_attributes SET value_num = 100, value_unit = 'liters' "
      "WHERE id = 'twelve_volume_l'",
    );

    expect(await repairCylinderVolumeCubicFeet(db), 0);
    expect(await litres(db, 'twelve'), 100);
  });

  test(
    'a database stamped 368 that never ran the rung is repaired on open',
    () async {
      // Another build that claimed 368 for something else stamps the
      // version without this column or this repair; the backstop heals both.
      final db = AppDatabase(dbAt367(version: 368));
      addTearDown(db.close);

      expect(await litres(db, 'al80'), 11.1);
      expect(await litres(db, 'twelve'), 12);
    },
  );
}
