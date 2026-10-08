import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

import '../../../../helpers/test_database.dart';

/// A slot never outlives its trip, and a tank link never outlives the
/// dive's membership of that trip (issue #2325).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late TripCylinderRepository cylinders;
  late String tripA;
  late String tripB;
  late String slotA;
  late String slotB;

  final at = DateTime.utc(2026, 3, 9, 8, 0);

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

  Future<void> insertDiveWithTank(
    String diveId,
    String tankId, {
    String? tripId,
    required String cylinderId,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: at.millisecondsSinceEpoch,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: tankId, diveId: diveId).copyWith(
            tripCylinderId: Value(cylinderId),
            endPressure: const Value(60.0),
          ),
        );
  }

  Future<String?> linkOf(String tankId) async =>
      (await db
              .customSelect(
                'SELECT trip_cylinder_id FROM dive_tanks WHERE id = ?',
                variables: [Variable<String>(tankId)],
              )
              .getSingle())
          .readNullable<String>('trip_cylinder_id');

  Future<int> tombstonesFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log '
                'WHERE entity_type = ? AND record_id = ?',
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    cylinders = TripCylinderRepository();
    tripA = (await trips.createTrip(trip('Bonaire'))).id;
    tripB = (await trips.createTrip(trip('Curacao'))).id;
    slotA = (await cylinders.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripA,
        label: 'A',
        createdAt: at,
        updatedAt: at,
      ),
    )).id;
    slotB = (await cylinders.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripB,
        label: 'B',
        createdAt: at,
        updatedAt: at,
      ),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  test(
    'deleting a trip takes its slots, tombstones them and clears links',
    () async {
      await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

      await trips.deleteTrip(tripA);

      expect(await cylinders.getCylindersForTrip(tripA), isEmpty);
      expect(await cylinders.getCylindersForTrip(tripB), hasLength(1));
      expect(await tombstonesFor('tripCylinders', slotA), 1);
      expect(await linkOf('t1'), isNull);
      // The dive itself survives, off the trip, with its tank data intact.
      final tank = await db
          .customSelect("SELECT end_pressure FROM dive_tanks WHERE id = 't1'")
          .getSingle();
      expect(tank.read<double>('end_pressure'), 60);
    },
  );

  test('removing a dive from its trip drops its links', () async {
    await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

    await trips.removeDiveFromTrip('d1');

    expect(await linkOf('t1'), isNull);
    expect(await cylinders.getCylindersForTrip(tripA), hasLength(1));
  });

  test(
    'assigning a dive to another trip drops links into the old one',
    () async {
      await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

      await trips.assignDiveToTrip('d1', tripB);

      expect(await linkOf('t1'), isNull);
    },
  );

  test('assigning a dive to the trip its slot is on keeps the link', () async {
    // A dive that already carries a link into trip A, then is (re)assigned
    // to trip A: nothing to drop.
    await insertDiveWithTank('d1', 't1', tripId: null, cylinderId: slotA);

    await trips.assignDiveToTrip('d1', tripA);

    expect(await linkOf('t1'), slotA);
  });

  test('the batch assign drops foreign links per dive', () async {
    await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);
    await insertDiveWithTank('d2', 't2', tripId: tripB, cylinderId: slotB);

    await trips.assignDivesToTrip(['d1', 'd2'], tripB);

    expect(await linkOf('t1'), isNull);
    expect(await linkOf('t2'), slotB);
  });

  test(
    'moving or removing a dive tells sync, so the cleared links go out',
    () async {
      await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

      final moved = SyncEventBus.changes.first;
      await trips.assignDiveToTrip('d1', tripB);
      await expectLater(moved.timeout(const Duration(seconds: 1)), completes);

      await insertDiveWithTank('d2', 't2', tripId: tripB, cylinderId: slotB);
      final removed = SyncEventBus.changes.first;
      await trips.removeDiveFromTrip('d2');
      await expectLater(removed.timeout(const Duration(seconds: 1)), completes);
    },
  );

  test('a failed move leaves the links as they were', () async {
    await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

    // A trip id that does not exist fails the move on the foreign key.
    await expectLater(
      trips.assignDiveToTrip('d1', 'no-such-trip'),
      throwsA(anything),
    );

    expect(await linkOf('t1'), slotA);
  });
}
