import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/dive_gear_usage_sql.dart';

import '../../../../helpers/test_database.dart';

/// Every way an item is on a dive (issue #2853).
void main() {
  late AppDatabase db;
  const t = 1000;

  Future<void> addDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );

  Future<void> addItem(String id) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'other',
          createdAt: t,
          updatedAt: t,
          diverId: const Value('bill'),
        ),
      );

  Future<void> addDive(String id, String diver) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diver),
          diveDateTime: t,
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> addTank(
    String id,
    String dive, {
    String? cylinder,
    String? regulator,
    String? serial,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(id: id, diveId: dive).copyWith(
          equipmentId: Value(cylinder),
          regulatorEquipmentId: Value(regulator),
          transmitterSerial: Value(serial),
        ),
      );

  Future<void> addTransmitter(String id, String diver, String serial) => db
      .into(db.transmitters)
      .insert(
        TransmittersCompanion.insert(
          id: id,
          label: id,
          tankRole: 'backGas',
          createdAt: t,
          updatedAt: t,
          diverId: Value(diver),
          transmitterSerial: Value(serial),
          transmitterEquipmentId: const Value('txItem'),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    for (final d in ['bill', 'anna']) {
      await addDiver(d);
    }
    for (final i in ['mask', 'tank', 'reg', 'txItem']) {
      await addItem(i);
    }
    await addDive('b1', 'bill');
    await addDive('a1', 'anna');
  });

  tearDown(tearDownTestDatabase);

  Set<(String, String, String)> asSet(
    List<({String diveId, String equipmentId, String linkKind})> rows,
  ) => {for (final r in rows) (r.diveId, r.equipmentId, r.linkKind)};

  test('one row per way an item is on a dive', () async {
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'b1', equipmentId: 'mask'),
        );
    await addTank('t1', 'b1', cylinder: 'tank', regulator: 'reg', serial: 'A1');
    await addTransmitter('tx', 'bill', 'A1');
    expect(asSet(await gearUsageForDives(db, ['b1'])), {
      ('b1', 'mask', 'gearList'),
      ('b1', 'tank', 'tankCylinder'),
      ('b1', 'reg', 'tankRegulator'),
      ('b1', 'txItem', 'transmitter'),
    });
  });

  test('a blank or all-zero serial is no transmitter', () async {
    await addTank('t1', 'b1', serial: '000');
    await addTank('t2', 'b1', serial: '  ');
    await addTransmitter('tx0', 'bill', '000');
    expect(await gearUsageForDives(db, ['b1']), isEmpty);
  });

  test("a profile's registry does not match another profile's dive", () async {
    await addTank('t1', 'a1', serial: 'A1');
    await addTransmitter('tx', 'bill', 'A1');
    expect(await gearUsageForDives(db, ['a1']), isEmpty);
  });

  test('only the given dives are read', () async {
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'b1', equipmentId: 'mask'),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'a1', equipmentId: 'mask'),
        );
    expect(asSet(await gearUsageForDives(db, ['a1'])), {
      ('a1', 'mask', 'gearList'),
    });
    expect(await gearUsageForDives(db, const []), isEmpty);
  });
}
