import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v351: `dive_tanks.transmitter_slot`, the physical transmitter slot
/// a tank's pressures came from (issue #4347). A nullable column only; the
/// app fills it from downloads, imports and a runtime backfill, never from a
/// rung.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, transmitter_serial TEXT)',
      );
      rawDb.execute("INSERT INTO dive_tanks VALUES ('t1', 'd1', '180777')");
    },
  );

  Future<List<String>> columnsOf(AppDatabase db, String table) async =>
      (await db.customSelect("PRAGMA table_info('$table')").get())
          .map((c) => c.read<String>('name'))
          .toList();

  test('v351 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(351));
    expect(AppDatabase.migrationVersions, contains(351));
    expect(
      AppDatabase.migrationStepCount(349),
      AppDatabase.migrationStepCount(351) + 1,
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(351));
  });

  test('upgrading from v347 adds an empty transmitter_slot', () async {
    final db = AppDatabase(dbAt(347));
    addTearDown(db.close);
    final tank = await db
        .customSelect(
          'SELECT transmitter_serial, transmitter_slot FROM dive_tanks',
        )
        .getSingle();
    expect(tank.read<String>('transmitter_serial'), '180777');
    expect(tank.read<int?>('transmitter_slot'), isNull);
  });

  test('asserting the column twice is harmless', () async {
    final db = AppDatabase(dbAt(347));
    addTearDown(db.close);
    await db.assertTankTransmitterSlotColumnForTest();
    await db.assertTankTransmitterSlotColumnForTest();
    expect(await columnsOf(db, 'dive_tanks'), contains('transmitter_slot'));
  });
}
