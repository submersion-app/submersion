import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

/// Gear planned on a trip checklist (issue #4934): an item linked to an
/// equipment row is ticked by that gear being packed for the trip.
void main() {
  late TripChecklistRepository repository;
  late TripEquipmentRepository packs;
  late Trip testTrip;
  late TripChecklist testChecklist;

  TripChecklistItem item(String title, {String? equipmentId}) =>
      TripChecklistItem(
        id: '',
        checklistId: testChecklist.id,
        title: title,
        equipmentId: equipmentId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<EquipmentItem> gear(
    String name, {
    EquipmentType type = EquipmentType.bcd,
    EquipmentStatus status = EquipmentStatus.active,
  }) => EquipmentRepository().createEquipment(
    EquipmentItem(id: '', name: name, type: type, status: status),
  );

  setUp(() async {
    await setUpTestDatabase();
    repository = TripChecklistRepository();
    packs = TripEquipmentRepository();
    final start = DateTime(2026, 9, 10);
    testTrip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: start,
        endDate: start.add(const Duration(days: 7)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    testChecklist = await TripChecklistsRepository().createChecklist(
      tripId: testTrip.id,
      name: 'Checklist',
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'linked checklist items follow packing without duplicating state',
    () async {
      final bcd = await gear('BCD');
      final spare = await gear('Spare mask', type: EquipmentType.mask);
      final planned = await repository.createItem(
        item(bcd.name, equipmentId: bcd.id),
      );
      await repository.createItem(item(spare.name, equipmentId: spare.id));
      expect(await packs.equipmentIdsForTrip(testTrip.id), isEmpty);
      expect(
        (await repository.getByChecklistId(
          testChecklist.id,
        )).map((i) => i.isDone),
        [false, false],
      );

      await repository.toggleDone(planned.id, isDone: true);
      expect(await packs.equipmentIdsForTrip(testTrip.id), [bcd.id]);
      final packed = await repository.getAllItemsForTrip(testTrip.id);
      expect(packed.first.equipmentId, bcd.id);
      expect(packed.first.isDone, isTrue);
      expect(packed.first.completedAt, isNotNull);
      expect(packed.last.isDone, isFalse);
      expect(await repository.getProgressForTrips([testTrip.id]), {
        testTrip.id: (done: 1, total: 2),
      });

      // Changes made through the Gear tab or passport also drive the list.
      await packs.unpack(testTrip.id, bcd.id);
      expect(
        (await repository.getByChecklistId(testChecklist.id)).first.isDone,
        isFalse,
      );
      await packs.pack(testTrip.id, [bcd.id]);
      await repository.toggleDone(planned.id, isDone: false);
      expect(await packs.equipmentIdsForTrip(testTrip.id), isEmpty);

      await packs.pack(testTrip.id, [bcd.id]);
      await repository.deleteItem(planned.id);
      expect(await packs.equipmentIdsForTrip(testTrip.id), [bcd.id]);
    },
  );

  test('createItem answers a gear item as its packing, not the caller '
      'isDone', () async {
    final bcd = await gear('BCD');
    final fins = await gear('Fins', type: EquipmentType.fins);
    await packs.pack(testTrip.id, [fins.id]);

    final unpacked = await repository.createItem(
      item(
        bcd.name,
        equipmentId: bcd.id,
      ).copyWith(isDone: true, completedAt: DateTime(2026)),
    );
    expect(unpacked.isDone, isFalse);
    expect(unpacked.completedAt, isNull);

    final alreadyPacked = await repository.createItem(
      item(fins.name, equipmentId: fins.id),
    );
    expect(alreadyPacked.isDone, isTrue);
  });

  test('a gear item whose equipment is gone reads and ticks as a plain '
      'item', () async {
    final torch = await gear('Torch', type: EquipmentType.light);
    final planned = await repository.createItem(
      item(torch.name, equipmentId: torch.id),
    );
    await EquipmentRepository().deleteEquipment(torch.id);

    var read = (await repository.getByChecklistId(testChecklist.id)).single;
    expect(read.equipmentId, isNull);
    expect(read.isDone, isFalse);

    // The tick is the row's own: nothing is packed, and progress counts it.
    await repository.toggleDone(planned.id, isDone: true);
    expect(await packs.equipmentIdsForTrip(testTrip.id), isEmpty);
    read = (await repository.getByChecklistId(testChecklist.id)).single;
    expect(read.isDone, isTrue);
    expect(read.completedAt, isNotNull);
    expect(await repository.getProgressForTrips([testTrip.id]), {
      testTrip.id: (done: 1, total: 1),
    });

    await repository.toggleDone(planned.id, isDone: false);
    expect(
      (await repository.getByChecklistId(testChecklist.id)).single.isDone,
      isFalse,
    );
  });

  test('a gear item whose equipment is on the wishlist reads and ticks as a '
      'plain item, packing nothing', () async {
    final drysuit = await gear(
      'Drysuit',
      type: EquipmentType.drysuit,
      status: EquipmentStatus.wanted,
    );
    final planned = await repository.createItem(
      item(drysuit.name, equipmentId: drysuit.id),
    );

    await repository.toggleDone(planned.id, isDone: true);
    expect(await packs.equipmentIdsForTrip(testTrip.id), isEmpty);
    final read = (await repository.getByChecklistId(testChecklist.id)).single;
    expect(read.equipmentId, isNull);
    expect(read.isDone, isTrue);
    expect(await repository.getProgressForTrips([testTrip.id]), {
      testTrip.id: (done: 1, total: 1),
    });
  });

  test('gear the trip diver cannot use reads as a plain item until it is '
      'shared with them', () async {
    Future<Diver> diver(String name) => DiverRepository().createDiver(
      Diver(
        id: '',
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    final owner = await diver('Owner');
    final buddy = await diver('Buddy');
    final start = DateTime(2026, 10, 1);
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Buddy trip',
        diverId: buddy.id,
        startDate: start,
        endDate: start.add(const Duration(days: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final checklist = await TripChecklistsRepository().createChecklist(
      tripId: trip.id,
      name: 'Packing',
    );
    final wing = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'Wing',
        type: EquipmentType.bcd,
        diverId: owner.id,
      ),
    );
    final planned = await repository.createItem(
      item(wing.name, equipmentId: wing.id).copyWith(checklistId: checklist.id),
    );

    await repository.toggleDone(planned.id, isDone: true);
    expect(await packs.equipmentIdsForTrip(trip.id), isEmpty);
    expect(
      (await repository.getByChecklistId(checklist.id)).single.equipmentId,
      isNull,
    );

    await EquipmentShareRepository().shareMany(
      equipmentIds: [wing.id],
      diverIds: [buddy.id],
      actingDiverId: owner.id,
    );
    final shared = (await repository.getByChecklistId(checklist.id)).single;
    expect(shared.equipmentId, wing.id);
    expect(shared.isDone, isFalse);

    await repository.toggleDone(planned.id, isDone: true);
    expect(await packs.equipmentIdsForTrip(trip.id), [wing.id]);
  });

  test('a viewer reads the owner\'s hidden gear as a plain item until it is '
      'shared with them', () async {
    Future<Diver> diver(String name) => DiverRepository().createDiver(
      Diver(
        id: '',
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    final owner = await diver('Owner');
    final sharee = await diver('Sharee');
    final start = DateTime(2026, 10, 1);
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Shared trip',
        diverId: owner.id,
        startDate: start,
        endDate: start.add(const Duration(days: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final checklist = await TripChecklistsRepository().createChecklist(
      tripId: trip.id,
      name: 'Packing',
    );
    final wing = await EquipmentRepository().createEquipment(
      EquipmentItem(
        id: '',
        name: 'Wing',
        type: EquipmentType.bcd,
        diverId: owner.id,
      ),
    );
    await repository.createItem(
      item(wing.name, equipmentId: wing.id).copyWith(checklistId: checklist.id),
    );
    await packs.pack(trip.id, [wing.id]);

    final asOwner = (await repository.getByChecklistId(
      checklist.id,
      viewerId: owner.id,
    )).single;
    expect(asOwner.equipmentId, wing.id);
    expect(asOwner.isDone, isTrue);

    // The Gear tab hides the owner's private wing from the sharee, so the
    // row neither names it nor shows its packing.
    final asSharee = (await repository.getAllItemsForTrip(
      trip.id,
      viewerId: sharee.id,
    )).single;
    expect(asSharee.equipmentId, isNull);
    expect(asSharee.isDone, isFalse);

    // Progress counts as each diver reads the rows.
    expect(
      await repository.getProgressForTrips([trip.id], viewerId: sharee.id),
      {trip.id: (done: 0, total: 1)},
    );
    expect(
      await repository.getProgressForTrips([trip.id], viewerId: owner.id),
      {trip.id: (done: 1, total: 1)},
    );

    // The trip page saves the sharee's tick on that plain row through
    // updateItem: it ticks the row itself and never touches the packing.
    await packs.unpack(trip.id, wing.id);
    await repository.updateItem(
      asSharee.copyWith(isDone: true, completedAt: DateTime(2026)),
    );
    expect(await packs.equipmentIdsForTrip(trip.id), isEmpty);
    expect(
      (await repository.getByChecklistId(
        checklist.id,
        viewerId: sharee.id,
      )).single.isDone,
      isTrue,
    );
    expect(
      (await repository.getByChecklistId(
        checklist.id,
        viewerId: owner.id,
      )).single.isDone,
      isFalse,
    );
    await packs.pack(trip.id, [wing.id]);

    await EquipmentShareRepository().shareMany(
      equipmentIds: [wing.id],
      diverIds: [sharee.id],
      actingDiverId: owner.id,
    );
    final shared = (await repository.getByChecklistId(
      checklist.id,
      viewerId: sharee.id,
    )).single;
    expect(shared.equipmentId, wing.id);
    expect(shared.isDone, isTrue);
    expect(
      await repository.getProgressForTrips([trip.id], viewerId: sharee.id),
      {trip.id: (done: 1, total: 1)},
    );
  });

  test('a trip handed to another diver ticks the checklist stream', () async {
    final tick = repository.watchTripChecklistChanges().first;
    await TripRepository().updateTrip(testTrip.copyWith(name: 'Renamed'));
    await expectLater(tick.timeout(const Duration(seconds: 5)), completes);
  });
}
