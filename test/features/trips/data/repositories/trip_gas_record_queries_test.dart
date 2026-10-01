import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveComputersCompanion,
        DiversCompanion,
        DivesCompanion,
        DiveTanksCompanion;
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TripCylinderRepository repository;
  late String tripId;
  late String otherTripId;
  late TripCylinder slot;
  late TripCylinder foreignSlot;

  final at = DateTime.utc(2026, 3, 9, 9);

  Future<String> trip(String name) async => (await TripRepository().createTrip(
    Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  )).id;

  Future<TripCylinder> cylinder(String trip, String label) =>
      repository.createCylinder(
        TripCylinder(
          id: '',
          tripId: trip,
          label: label,
          createdAt: at,
          updatedAt: at,
        ),
      );

  Future<void> dive(
    String id,
    int hour, {
    String? trip,
    String? diver,
    bool planned = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: DateTime.utc(2026, 3, 9, hour).millisecondsSinceEpoch,
          tripId: Value(trip ?? tripId),
          diverId: Value(diver),
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(isPlanned: Value(planned)),
      );

  Future<void> tankOn(
    String id,
    String diveId, {
    String? slotId,
    int order = 0,
    double? volume,
    String? computerId,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(id: id, diveId: diveId).copyWith(
          tripCylinderId: Value(slotId),
          tankOrder: Value(order),
          volume: Value(volume),
          computerId: Value(computerId),
          startPressure: const Value(200),
          endPressure: const Value(60),
          o2Percent: const Value(32),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TripCylinderRepository();
    tripId = await trip('Bonaire');
    otherTripId = await trip('Curacao');
    slot = await cylinder(tripId, 'Truck 1');
    foreignSlot = await cylinder(otherTripId, 'Reef 1');
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: 'Diver $id',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('record tanks carry the diver, size and mix, in dive order', () async {
    await dive('d2', 11, diver: 'b');
    await dive('d1', 9, diver: 'a');
    await tankOn('t2', 'd2', slotId: slot.id, volume: 11.1);
    await tankOn('t1', 'd1', slotId: slot.id, volume: 12);
    await tankOn('t0', 'd1'); // unlinked: not a record tank
    final tanks = await repository.getGasRecordTanksForTrip(tripId);
    expect(tanks.map((t) => t.tankId), ['t1', 't2']);
    expect(tanks.first.diverName, 'Diver a');
    expect(tanks.first.volume, 12);
    expect(tanks.first.startPressure, 200);
    expect(tanks.first.gasMix.o2, 32);
    expect(tanks.first.entryTime, DateTime.utc(2026, 3, 9, 9));
    expect(tanks.first.tripCylinderId, slot.id);
  });

  test('unlinked tanks skip planned dives, include foreign links', () async {
    await dive('d1', 9, diver: 'a');
    await dive('d3', 13, planned: true);
    await dive('d4', 15, trip: otherTripId);
    await tankOn('t1', 'd1', slotId: slot.id);
    await tankOn('t2', 'd1', order: 1); // no link: a gap
    await tankOn('t3', 'd1', order: 2, slotId: foreignSlot.id); // other trip
    await tankOn('t4', 'd3'); // planned dive: not a gap
    await tankOn('t5', 'd4'); // another trip's dive: not ours
    final gaps = await repository.getUnlinkedTanksForTrip(tripId);
    expect(gaps.map((g) => g.tankId), ['t2', 't3']);
    expect(gaps.first.diverName, 'Diver a');
    expect(gaps.first.diveId, 'd1');
  });

  test('a gap names the computer its tank row came from', () async {
    // Issue #2661: a dive from two computers whose tank rows were not
    // consolidated. The sheet tells the rows apart by their computer.
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'perdix',
            name: 'Perdix',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await dive('d1', 9, diver: 'a');
    await tankOn('t1', 'd1');
    await tankOn('t2', 'd1', order: 1, computerId: 'perdix');
    final gaps = await repository.getUnlinkedTanksForTrip(tripId);
    expect(gaps.map((g) => (g.tankId, g.computerId)), [
      ('t1', null),
      ('t2', 'perdix'),
    ]);
  });

  test('a trip with no dives has an empty record', () async {
    expect(await repository.getGasRecordTanksForTrip(tripId), isEmpty);
    expect(await repository.getUnlinkedTanksForTrip(tripId), isEmpty);
  });
}
