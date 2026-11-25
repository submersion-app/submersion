import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

import '../../../../helpers/test_database.dart';

/// Gear packed for a trip (issue #2338).
void main() {
  late AppDatabase db;
  late TripEquipmentRepository packs;
  late String t1;
  late String t2;
  late String bcd;
  late String tank;

  Trip trip(String name) {
    final now = DateTime.now();
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<String> item(String name, EquipmentType type) async =>
      (await EquipmentRepository().createEquipment(
        EquipmentItem(id: '', name: name, type: type),
      )).id;

  Future<int> tombstones() async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = ?',
                variables: const [
                  Variable<String>(TripEquipmentRepository.entity),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<int> rows() async =>
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM trip_equipment')
              .getSingle())
          .read<int>('n');

  setUp(() async {
    db = await setUpTestDatabase();
    packs = TripEquipmentRepository();
    t1 = (await TripRepository().createTrip(trip('Bonaire'))).id;
    t2 = (await TripRepository().createTrip(trip('Curacao'))).id;
    bcd = await item('BCD', EquipmentType.bcd);
    tank = await item('Faber 12', EquipmentType.tank);
  });

  tearDown(tearDownTestDatabase);

  test('pack adds each pair once and marks it pending', () async {
    expect(await packs.pack(t1, [bcd, tank]), 2);
    expect(await packs.pack(t1, [bcd]), 0);
    expect((await packs.equipmentIdsForTrip(t1)).toSet(), {bcd, tank});
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.where((r) => r.entityType == TripEquipmentRepository.entity),
      hasLength(2),
    );
  });

  test('unpack removes the pair and tombstones it', () async {
    await packs.pack(t1, [bcd]);
    await packs.unpack(t1, bcd);
    expect(await packs.equipmentIdsForTrip(t1), isEmpty);
    expect(await tombstones(), 1);
  });

  test('bag assignments move, clear, and stay on the selected trip', () async {
    final first = await item('Roller', EquipmentType.bag);
    final second = await item('Carry-on', EquipmentType.bag);
    await packs.pack(t1, [first, second]);
    await packs.pack(t2, [first]);

    await packs.packInBag(t1, bcd, first);
    expect(await packs.bagAssignmentsForTrip(t1), {bcd: first});
    expect(await packs.bagAssignmentsForTrip(t2), isEmpty);
    await packs.assignBag(t1, bcd, second);
    expect(await packs.bagAssignmentsForTrip(t1), {bcd: second});

    await expectLater(packs.assignBag(t1, bcd, tank), throwsStateError);
    await packs.unpack(t1, second);
    expect(await packs.bagAssignmentsForTrip(t1), isEmpty);
    expect(await packs.equipmentIdsForTrip(t1), unorderedEquals([first, bcd]));

    await packs.assignBag(t1, bcd, first);
    await packs.unpack(t1, bcd);
    expect(await packs.bagAssignmentsForTrip(t1), isEmpty);
  });

  test('a bag chosen before it left the trip packs the gear loose', () async {
    final roller = await item('Roller', EquipmentType.bag);
    await packs.pack(t1, [roller]);
    await packs.pack(t2, [roller]);
    await packs.packInBag(t1, bcd, roller);

    // Unpacked elsewhere, while a sitting still held it as the choice.
    await packs.unpack(t2, roller);
    await packs.packInBag(t2, tank, roller);
    expect((await packs.equipmentIdsForTrip(t2)).toSet(), {tank});
    expect(await packs.bagAssignmentsForTrip(t2), isEmpty);

    await packs.unpack(t1, roller);
    await packs.pack(t1, [roller]);
    await packs.assignBag(t1, tank, roller, orLoose: true);
    expect(await packs.bagAssignmentsForTrip(t1), isEmpty);
  });

  test('gear whose bag stopped being a bag reads loose', () async {
    final roller = await item('Roller', EquipmentType.bag);
    await packs.pack(t1, [roller]);
    await packs.packInBag(t1, bcd, roller);
    await db.customStatement(
      "UPDATE equipment SET type = 'other' WHERE id = ?",
      [roller],
    );
    expect(await packs.bagAssignmentsForTrip(t1), isEmpty);
  });

  test(
    'gear whose bag row was dropped by an older client reads loose',
    () async {
      final roller = await item('Roller', EquipmentType.bag);
      await packs.pack(t1, [roller]);
      await packs.packInBag(t1, bcd, roller);
      await db.customStatement(
        'DELETE FROM trip_equipment WHERE trip_id = ? AND equipment_id = ?',
        [t1, roller],
      );
      expect(await packs.bagAssignmentsForTrip(t1), isEmpty);
    },
  );

  test('tripIdsForEquipment lists the trips an item is packed for', () async {
    await packs.pack(t1, [bcd]);
    await packs.pack(t2, [bcd]);
    expect(await packs.tripIdsForEquipment(bcd), {t1, t2});
  });

  test('deleting a trip tombstones its packed rows', () async {
    await packs.pack(t1, [bcd]);
    await TripRepository().deleteTrip(t1);
    expect(await rows(), 0);
    expect(await tombstones(), 1);
  });

  test('deleting an item tombstones its packed rows', () async {
    await packs.pack(t1, [bcd]);
    await packs.pack(t2, [bcd]);
    await EquipmentRepository().deleteEquipment(bcd);
    expect(await rows(), 0);
    expect(await tombstones(), 2);
  });

  test('a slot links an item to its trip', () async {
    final at = DateTime.utc(2026, 3, 9);
    await TripCylinderRepository().createCylinder(
      TripCylinder(
        id: '',
        tripId: t2,
        equipmentId: tank,
        label: 'A',
        createdAt: at,
        updatedAt: at,
      ),
    );
    expect(await TripCylinderRepository().tripIdsForEquipment(tank), {t2});
  });

  test('the change tick fires on pack and unpack', () async {
    var ticks = 0;
    final sub = packs.watchChanges().listen((_) => ticks++);
    addTearDown(sub.cancel);
    await packs.pack(t1, [bcd]);
    await Future<void>.delayed(Duration.zero);
    final afterPack = ticks;
    expect(afterPack, greaterThan(0));
    await packs.unpack(t1, bcd);
    await Future<void>.delayed(Duration.zero);
    expect(ticks, greaterThan(afterPack));
  });
}
