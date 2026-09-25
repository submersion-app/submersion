import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, TripCylindersCompanion;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive_tanks.trip_cylinder_id link (v228, issue #2325): user-authored,
/// so an edit writes it and a rebuild must carry it; meaningless outside its
/// trip, so a move to another trip drops it.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  late String tripA;
  late String tripB;

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

  Future<void> insertSlot(String id, String tripId) => db
      .into(db.tripCylinders)
      .insert(
        TripCylindersCompanion.insert(
          id: id,
          tripId: tripId,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<String?> linkOf(String tankId) async =>
      (await db
              .customSelect(
                'SELECT trip_cylinder_id FROM dive_tanks WHERE id = ?',
                variables: [Variable<String>(tankId)],
              )
              .getSingle())
          .readNullable<String>('trip_cylinder_id');

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    final trips = TripRepository();
    tripA = (await trips.createTrip(trip('Bonaire'))).id;
    tripB = (await trips.createTrip(trip('Curacao'))).id;
    await insertSlot('slot-a', tripA);
    await insertSlot('slot-b', tripB);
  });
  tearDown(tearDownTestDatabase);

  test(
    'the link survives create, read and update, and clears on request',
    () async {
      final dive = createTestDiveWithBottomTime(id: 'd1').copyWith(
        tripId: tripA,
        tanks: const [
          DiveTank(id: 't1', gasMix: GasMix(o2: 32), tripCylinderId: 'slot-a'),
        ],
      );
      await repo.createDive(dive);

      final loaded = await repo.getDiveById('d1');
      expect(loaded!.tanks.single.tripCylinderId, 'slot-a');

      // An edit that rebuilds the tank keeps the link.
      await repo.updateDive(
        loaded.copyWith(tanks: [loaded.tanks.single.copyWith(endPressure: 60)]),
      );
      expect(
        (await repo.getDiveById('d1'))!.tanks.single.tripCylinderId,
        'slot-a',
      );

      // And an explicit clear removes it.
      final linked = (await repo.getDiveById('d1'))!;
      await repo.updateDive(
        linked.copyWith(
          tanks: [linked.tanks.single.copyWith(clearTripCylinderId: true)],
        ),
      );
      expect(
        (await repo.getDiveById('d1'))!.tanks.single.tripCylinderId,
        isNull,
      );
    },
  );

  test('the list mapper carries the link too', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tripId: tripA,
        tanks: const [DiveTank(id: 't1', tripCylinderId: 'slot-a')],
      ),
    );
    final byIds = await repo.getDivesByIds(['d1']);
    expect(byIds.single.tanks.single.tripCylinderId, 'slot-a');
  });

  test(
    'moving the dive to another trip drops a link into the old trip',
    () async {
      await repo.createDive(
        createTestDiveWithBottomTime(id: 'd1').copyWith(
          tripId: tripA,
          tanks: const [DiveTank(id: 't1', tripCylinderId: 'slot-a')],
        ),
      );
      final dive = (await repo.getDiveById('d1'))!;

      // Same trip: the link stays.
      await repo.updateDive(dive.copyWith(notes: 'Salt Pier'));
      expect(await linkOf('t1'), 'slot-a');

      // Another trip: the slot is not on it, so the link goes.
      await repo.updateDive(dive.copyWith(tripId: tripB));
      expect(await linkOf('t1'), isNull);
    },
  );

  test('a dive created on no trip cannot hold a link', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', tripCylinderId: 'slot-a')],
      ),
    );
    expect(await linkOf('t1'), isNull);
  });

  test('a bulk replace stamps the link only when restoring', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(tripId: tripA),
    );
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd2').copyWith(tripId: tripA),
    );
    const template = DiveTank(id: 'tpl', tripCylinderId: 'slot-a');

    // A template copied from a linked tank must not put that slot on every
    // dive it lands on.
    await repo.bulkReplaceTanks(['d1'], const [template]);
    final d1 = (await repo.getDiveById('d1'))!;
    expect(d1.tanks.single.tripCylinderId, isNull);

    // An undo restoring captured rows writes what it captured.
    await repo.bulkReplaceTanks(['d2'], const [template], restoreLinks: true);
    final d2 = (await repo.getDiveById('d2'))!;
    expect(d2.tanks.single.tripCylinderId, 'slot-a');
  });
}
