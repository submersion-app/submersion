import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// A slot's equipment link and a fill's dive center link are cleared by
/// SQLite when the parent goes (ON DELETE SET NULL), but that write reaches
/// no peer. Every path that deletes gear or a center must clear the link
/// itself and stage the row, as the dive tank links already are.
void main() {
  late AppDatabase db;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDiver(String id) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: const Value(stale),
            updatedAt: const Value(stale),
          ),
        );
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion(
            id: Value('settings-$id'),
            diverId: Value(id),
            createdAt: const Value(stale),
            updatedAt: const Value(stale),
          ),
        );
  }

  Future<void> insertParents({String owner = 'diver-a'}) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'cyl-a',
            name: 'HP100',
            type: 'tank',
            diverId: Value(owner),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'dc-a',
            name: 'Dive Friends',
            diverId: Value(owner),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
  }

  Future<void> insertSlotAndFill({String tripOwner = 'diver-b'}) async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip-b',
            name: 'Bonaire',
            startDate: stale,
            endDate: stale,
            diverId: Value(tripOwner),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.tripCylinders)
        .insert(
          TripCylindersCompanion.insert(
            id: 'slot-b',
            tripId: 'trip-b',
            equipmentId: const Value('cyl-a'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.tripCylinderEvents)
        .insert(
          TripCylinderEventsCompanion.insert(
            id: 'fill-b',
            tripCylinderId: 'slot-b',
            kind: 'fill',
            occurredAt: stale,
            diveCenterId: const Value('dc-a'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
  }

  Future<int> pendingCountFor(String entityType, String recordId) async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? "
          "AND record_id = ? AND sync_status = 'pending'",
          variables: [Variable<String>(entityType), Variable<String>(recordId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<String?> slotEquipment() async =>
      (await db
              .customSelect(
                "SELECT equipment_id FROM trip_cylinders WHERE id = 'slot-b'",
              )
              .getSingle())
          .readNullable<String>('equipment_id');

  Future<String?> fillCenter() async =>
      (await db
              .customSelect(
                "SELECT dive_center_id FROM trip_cylinder_events WHERE id = 'fill-b'",
              )
              .getSingle())
          .readNullable<String>('dive_center_id');

  test('deleting gear clears and stages the slot that held it', () async {
    await insertDiver('diver-a');
    await insertDiver('diver-b');
    await insertParents();
    await insertSlotAndFill();

    await EquipmentRepository().deleteEquipment('cyl-a');

    expect(await slotEquipment(), isNull);
    expect(await pendingCountFor('tripCylinders', 'slot-b'), 1);
  });

  test('deleting a dive center clears and stages the fills there', () async {
    await insertDiver('diver-a');
    await insertDiver('diver-b');
    await insertParents();
    await insertSlotAndFill();

    await DiveCenterRepository().deleteDiveCenter('dc-a');

    expect(await fillCenter(), isNull);
    expect(await pendingCountFor('tripCylinderEvents', 'fill-b'), 1);
  });

  test(
    "deleting a diver clears and stages another diver's slot and fill",
    () async {
      // Bob's trip slot holds Alice's cylinder and was filled at Alice's
      // center. Removing Alice deletes both; Bob's rows survive, unlinked.
      await insertDiver('diver-a');
      await insertDiver('diver-b');
      await insertParents();
      await insertSlotAndFill();

      await DiverRepository().deleteDiverWithReassignment('diver-a');

      expect(await slotEquipment(), isNull);
      expect(await fillCenter(), isNull);
      expect(await pendingCountFor('tripCylinders', 'slot-b'), 1);
      expect(await pendingCountFor('tripCylinderEvents', 'fill-b'), 1);
    },
  );
}
