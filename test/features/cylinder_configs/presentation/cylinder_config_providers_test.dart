import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
// Both names collide with the generated Drift row classes; the domain
// entities are the ones under test here.
import 'package:submersion/core/database/database.dart'
    hide CylinderConfig, CylinderConfigItem;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderConfigRepository repo;
  final now = DateTime.utc(2026, 8, 5);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CylinderConfigRepository();
    final t = now.millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd2',
            name: 'd2',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'rb-1',
            name: 'JJ',
            type: 'rebreather',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    "cylinderConfigsProvider returns only the active diver's configs",
    () async {
      await repo.createConfig(diverId: 'd1', name: 'Mine');
      await repo.createConfig(diverId: 'd2', name: 'Someone else');

      final configs = await makeContainer().read(
        cylinderConfigsProvider.future,
      );
      expect(configs.map((c) => c.name), ['Mine']);
    },
  );

  test('cylinderConfigsProvider hydrates items', () async {
    final id = await repo.createConfig(diverId: 'd1', name: 'JJ trimix');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.diluent,
        o2Percent: 18,
        hePercent: 45,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final configs = await makeContainer().read(cylinderConfigsProvider.future);
    expect(configs.single.cylinderCount, 1);
    expect(configs.single.items.single.tankRole, TankRole.diluent);
  });

  test('cylinderConfigsForEquipmentProvider filters by unit', () async {
    await repo.createConfig(diverId: 'd1', equipmentId: 'rb-1', name: 'Owned');
    await repo.createConfig(diverId: 'd1', name: 'Generic');

    final owned = await makeContainer().read(
      cylinderConfigsForEquipmentProvider('rb-1').future,
    );
    expect(owned.map((c) => c.name), ['Owned']);
  });

  test('cylinderConfigProvider returns null for an unknown id', () async {
    final config = await makeContainer().read(
      cylinderConfigProvider('nope').future,
    );
    expect(config, isNull);
  });

  test('invalidating the list provider refetches', () async {
    final container = makeContainer();
    await repo.createConfig(diverId: 'd1', name: 'First');
    expect((await container.read(cylinderConfigsProvider.future)).length, 1);

    await repo.createConfig(diverId: 'd1', name: 'Second');
    container.invalidate(cylinderConfigsProvider);

    expect((await container.read(cylinderConfigsProvider.future)).length, 2);
  });
}
