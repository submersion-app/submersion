import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/query/trip_filter_query.dart';

import '../../../helpers/test_database.dart';

/// Trips by equipment through the compiled query (#2365).
void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final id in ['a', 'b', 'c']) {
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: id,
              diverId: const Value('me'),
              name: id,
              startDate: now,
              endDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    for (final (id, type) in [('reg', 'regulator'), ('tank', 'cylinder')]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: type,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    Future<void> dive(String id, String tripId) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: const Value('me'),
            tripId: Value(tripId),
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('d1', 'a');
    await dive('d2', 'b');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'reg'),
        );
    // A cylinder the transmitter registry matched to d2's tank.
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'dt2',
            diveId: 'd2',
            equipmentId: const Value('tank'),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(String equipmentId) => QueryIdSetRunner(
    db,
  ).ids(compileTripFilter(TripFilterState(equipmentId: equipmentId)));

  test('equipment selects the trips whose dives used it', () async {
    expect(await ids('reg'), {'a'});
    expect(
      (await EquipmentRepository().getTripIdsForEquipment('reg')).toSet(),
      {'a'},
    );
  });

  test('a transmitter-matched cylinder counts, as it does for dives', () async {
    // Ruling: the dive gear union counts it; getTripIdsForEquipment, which
    // reads only dive_equipment, missed this trip.
    expect(await ids('tank'), {'b'});
    expect(await EquipmentRepository().getTripIdsForEquipment('tank'), isEmpty);
  });

  test('no filter selects every trip', () async {
    expect(
      await QueryIdSetRunner(
        db,
      ).ids(compileTripFilter(const TripFilterState())),
      {'a', 'b', 'c'},
    );
  });
}
