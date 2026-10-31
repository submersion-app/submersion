import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/test_database.dart';

/// The item page's Trips row counts what it opens: the trips the list shows
/// for that item, however the item reached a dive (issue #4016).
void main() {
  const me = 'me';
  const item = 'item';

  late AppDatabase db;
  late ProviderContainer container;

  /// Long enough for a debounced tick to fire and the refresh to settle.
  final settle = DiveRepository.changeTickDebounce * 2;

  Future<void> addDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );

  Future<void> addTrip(String id, {String diver = me, String? parent}) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: 1,
          endDate: 1,
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(diverId: Value(diver), parentTripId: Value(parent)),
      );

  Future<void> addDive(
    String id,
    String tripId, {
    bool planned = false,
    bool excludedFromStats = false,
    String diver = me,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 1,
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(
          diverId: Value(diver),
          tripId: Value(tripId),
          isPlanned: Value(planned),
          excludedFromStats: Value(excludedFromStats),
        ),
      );

  Future<void> link(String diveId, [String equipmentId = item]) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  Future<void> addEquipment(String id, String type) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: type,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  /// What the list shows for [equipmentId], as the row's link opens it.
  Future<Set<String>> listed([String equipmentId = item]) => container.read(
    queryFilteredTripIdsProvider(
      TripFilterState(equipmentId: equipmentId),
    ).future,
  );

  Future<int> rowCount([String equipmentId = item]) =>
      container.read(equipmentTripCountProvider(equipmentId).future);

  /// Holds both open, as the page and the list do, so a tick reaches them.
  void keepAlive() {
    final count = container.listen(equipmentTripCountProvider(item), (_, _) {});
    final ids = container.listen(
      queryFilteredTripIdsProvider(const TripFilterState(equipmentId: item)),
      (_, _) {},
    );
    addTearDown(count.close);
    addTearDown(ids.close);
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await addDiver(me);
    await addEquipment(item, 'bcd');
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => me),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  test('a cylinder and both regulator paths reach the trip', () async {
    await addEquipment('cylinder', 'tank');
    await addEquipment('first', 'regulator');
    await addEquipment('extra', 'regulator');
    await addTrip('A');
    await addDive('D', 'A');
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 'T', diveId: 'D').copyWith(
            equipmentId: const Value('cylinder'),
            regulatorEquipmentId: const Value('first'),
            extraRegulatorIds: const Value('["extra"]'),
          ),
        );

    for (final id in ['cylinder', 'first', 'extra']) {
      expect(await rowCount(id), 1, reason: id);
      expect(await listed(id), {'A'}, reason: id);
    }
  });

  test(
    'a trip with only a plan for the item is neither counted nor listed',
    () async {
      await addTrip('been');
      await addTrip('upcoming');
      await addDive('actual', 'been');
      await addDive('plan', 'upcoming', planned: true);
      await link('actual');
      await link('plan');

      expect(await rowCount(), 1);
      expect(await listed(), {'been'});
    },
  );

  test('the item must be on a dive that happened, not beside one', () async {
    await addTrip('A');
    await addDive('logged', 'A');
    await addDive('plan', 'A', planned: true);
    await link('plan');

    expect(await rowCount(), 0);
    expect(await listed(), isEmpty);
  });

  test('a dive excluded from statistics still counts', () async {
    await addTrip('A');
    await addDive('practice', 'A', excludedFromStats: true);
    await link('practice');

    expect(await rowCount(), 1);
    expect(await listed(), {'A'});
  });

  test(
    'a dive on a side trip counts the parent too, as the list shows it',
    () async {
      await addTrip('parent');
      await addTrip('side', parent: 'parent');
      await addDive('D', 'side');
      await link('D');

      expect(await rowCount(), 2);
      expect(await listed(), {'parent', 'side'});
    },
  );

  test('a hidden trip is neither counted nor listed', () async {
    await addTrip('A');
    await addTrip('B');
    await addDive('D1', 'A');
    await addDive('D2', 'B');
    await link('D1');
    await link('D2');
    await db
        .into(db.tripHides)
        .insert(
          TripHidesCompanion.insert(
            id: 'h',
            diverId: me,
            tripId: 'B',
            createdAt: 1,
          ),
        );

    expect(await rowCount(), 1);
    expect(await listed(), {'A'});
  });

  test('another diver\'s dive on a shared trip does not count', () async {
    await addDiver('buddy');
    await addTrip('A');
    await addDive('D', 'A', diver: 'buddy');
    await link('D');

    expect(await rowCount(), 0);
    expect(await listed(), isEmpty);
  });

  test('hiding a trip refreshes an open row', () async {
    await addTrip('A');
    await addDive('D', 'A');
    await link('D');
    keepAlive();
    expect(await rowCount(), 1);

    await db
        .into(db.tripHides)
        .insert(
          TripHidesCompanion.insert(
            id: 'h',
            diverId: me,
            tripId: 'A',
            createdAt: 1,
          ),
        );
    await Future<void>.delayed(settle);

    expect(await rowCount(), 0);
  });

  test('a tank naming the item refreshes an open row', () async {
    await addTrip('A');
    await addDive('D', 'A');
    keepAlive();
    expect(await rowCount(), 0);

    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'T',
            diveId: 'D',
          ).copyWith(equipmentId: const Value(item)),
        );
    await Future<void>.delayed(settle);

    expect(await rowCount(), 1);
  });

  test('logging a plan refreshes an open row', () async {
    await addTrip('A');
    await addDive('plan', 'A', planned: true);
    await link('plan');
    keepAlive();
    expect(await rowCount(), 0);

    await (db.update(db.dives)..where((t) => t.id.equals('plan'))).write(
      const DivesCompanion(isPlanned: Value(false)),
    );
    await Future<void>.delayed(settle);

    expect(await rowCount(), 1);
  });
}
