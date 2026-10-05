import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final id in ['reg', 'bcd']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test(
    'current locations join moves to places; cleared items are absent',
    () async {
      final garage = await EquipmentLocationRepository().createLocation(
        diverId: 'me',
        name: 'Garage',
        kind: EquipmentLocationKind.storage,
      );
      final moves = EquipmentLocationMoveRepository();
      await moves.recordMoves(
        equipmentIds: ['reg', 'bcd'],
        locationId: garage.id,
        movedAt: DateTime(2026),
      );
      await moves.recordMoves(
        equipmentIds: ['bcd'],
        locationId: null,
        movedAt: DateTime(2026, 2),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final current = await container.read(
        currentEquipmentLocationsProvider.future,
      );
      expect(current.keys, ['reg']);
      expect(current['reg']?.name, 'Garage');
    },
  );

  test('group by location defaults off and round-trips', () async {
    final repo = AppSettingsRepository();
    expect(await repo.getEquipmentGroupByLocation(), isFalse);
    await repo.setEquipmentGroupByLocation(true);
    expect(await repo.getEquipmentGroupByLocation(), isTrue);
    await repo.setEquipmentGroupByLocation(false);
    expect(await repo.getEquipmentGroupByLocation(), isFalse);
  });
}
