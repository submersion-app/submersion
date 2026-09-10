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
