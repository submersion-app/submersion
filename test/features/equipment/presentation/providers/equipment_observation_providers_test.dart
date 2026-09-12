import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentObservationRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    container = ProviderContainer(
      overrides: [
        equipmentObservationRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test(
    'dive numbers for an item\'s check-ins, and a renumber reaches them',
    () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd2',
              diveDateTime: 2000,
              createdAt: 2000,
              updatedAt: 2000,
            ).copyWith(diveNumber: const Value(13)),
          );
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        const DivesCompanion(diveNumber: Value(12)),
      );
      for (final diveId in ['d1', 'd2', null]) {
        await repo.create(
          equipmentId: 'reg',
          diveId: diveId,
          observedAt: DateTime.utc(2026),
          status: ObservationStatus.ok,
        );
      }
      final sub = container.listen(
        observationDiveNumbersProvider('reg'),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        await container.read(observationDiveNumbersProvider('reg').future),
        {'d1': 12, 'd2': 13},
      );

      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        const DivesCompanion(diveNumber: Value(20)),
      );
      Map<String, int?>? numbers;
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        numbers = await container.read(
          observationDiveNumbersProvider('reg').future,
        );
        if (numbers?['d1'] == 20) break;
      }
      expect(numbers, {'d1': 20, 'd2': 13});
    },
  );

  test('both families refresh after a write', () async {
    final byItem = container.listen(
      observationsForEquipmentProvider('reg'),
      (_, _) {},
    );
    final byDive = container.listen(
      observationsForDiveProvider('d1'),
      (_, _) {},
    );
    addTearDown(byItem.close);
    addTearDown(byDive.close);
    expect(
      await container.read(observationsForEquipmentProvider('reg').future),
      isEmpty,
    );
    expect(
      await container.read(observationsForDiveProvider('d1').future),
      isEmpty,
    );

    await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.issue,
    );
    // The table tick is a stream; poll rather than pump the event queue.
    for (var i = 0; i < 50; i++) {
      final v = container.read(observationsForEquipmentProvider('reg')).value;
      if (v != null && v.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      await container.read(observationsForEquipmentProvider('reg').future),
      hasLength(1),
    );
    expect(
      await container.read(observationsForDiveProvider('d1').future),
      hasLength(1),
    );
  });
}
