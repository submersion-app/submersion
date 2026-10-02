import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiversCompanion, DivesCompanion, DiveTanksCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TripCylinderRepository cylinders;
  late String tripId;

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        gasModelProvider.overrideWithValue(GasModel.ideal),
        defaultCurrencyProvider.overrideWithValue('USD'),
      ],
    );
    addTearDown(container.dispose);
    cylinders = TripCylinderRepository();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  test('gathers slots, fills, tanks and gaps into the record', () async {
    final at = DateTime.utc(2026, 3, 9, 7);
    final slot = await cylinders.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await cylinders.createEvent(
      TripCylinderEvent(
        id: '',
        tripCylinderId: slot.id,
        kind: TripCylinderEventKind.fill,
        occurredAt: at,
        bottleLabel: '14',
        pressure: 200,
        o2Percent: 32,
        cost: 10,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2026, 3, 9, 9).millisecondsSinceEpoch,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, link) in [('t1', slot.id), ('t2', null)]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: id, diveId: 'd1').copyWith(
              tripCylinderId: Value(link),
              volume: const Value(11.1),
              startPressure: const Value(200),
              endPressure: const Value(60),
              o2Percent: const Value(32),
            ),
          );
    }

    final record = await container.read(tripGasRecordProvider(tripId).future);
    expect(record.rows.single.bottleLabel, '14');
    // 11.1 L x 140 bar, ideal gas.
    expect(record.rows.single.litres, closeTo(1554, 0.001));
    expect(record.fillsLogged, 1);
    expect(record.costs.single.key, 'USD');
    expect(record.unlinked.single.tankId, 't2');
  });

  test('linking a tank refreshes the record', () async {
    final at = DateTime.utc(2026, 3, 9, 7);
    final slot = await cylinders.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2026, 3, 9, 9).millisecondsSinceEpoch,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 't1', diveId: 'd1'));
    // Auto-disposed: keep it alive across the write, as the open tab does.
    final sub = container.listen(tripGasRecordProvider(tripId), (_, _) {});
    addTearDown(sub.close);
    final before = await container.read(tripGasRecordProvider(tripId).future);
    expect(before.unlinked.single.tankId, 't1');
    expect(before.rows, isEmpty);

    await (db.update(db.diveTanks)..where((t) => t.id.equals('t1'))).write(
      DiveTanksCompanion(tripCylinderId: Value(slot.id)),
    );
    await pumpEventQueue();

    final after = await container.read(tripGasRecordProvider(tripId).future);
    expect(after.unlinked, isEmpty);
    expect(after.rows.single.tank.tankId, 't1');
  });

  test('renaming a diver refreshes the record', () async {
    // A rename writes only the divers row, yet the record and its export
    // name each tank's diver (issue #2666).
    final at = DateTime.utc(2026, 3, 9, 7);
    final slot = await cylinders.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        workingPressure: 207,
        createdAt: at,
        updatedAt: at,
      ),
    );
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'v1',
            name: 'Ana',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2026, 3, 9, 9).millisecondsSinceEpoch,
            tripId: Value(tripId),
            diverId: const Value('v1'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, link) in [('t1', slot.id), ('t2', null)]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: id,
              diveId: 'd1',
            ).copyWith(tripCylinderId: Value(link)),
          );
    }
    // Auto-disposed: keep it alive across the write, as the open tab does.
    final sub = container.listen(tripGasRecordProvider(tripId), (_, _) {});
    addTearDown(sub.close);
    final before = await container.read(tripGasRecordProvider(tripId).future);
    expect(before.rows.single.tank.diverName, 'Ana');
    expect(before.unlinked.single.diverName, 'Ana');

    await (db.update(db.divers)..where((v) => v.id.equals('v1'))).write(
      const DiversCompanion(name: Value('Ana Silva')),
    );
    await pumpEventQueue();

    final after = await container.read(tripGasRecordProvider(tripId).future);
    expect(after.rows.single.tank.diverName, 'Ana Silva');
    expect(after.unlinked.single.diverName, 'Ana Silva');
  });
}
