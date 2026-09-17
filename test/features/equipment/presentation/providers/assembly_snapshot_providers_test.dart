import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_snapshot_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

import '../../../../helpers/test_database.dart';

/// The part statuses the dive gear tree needs to tell a missing part from a
/// retired one (issue #1988).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed(
    String id, {
    String status = 'active',
    bool isActive = true,
    String? diverId,
  }) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'hose',
          createdAt: 1,
          updatedAt: 1,
          status: Value(status),
          isActive: Value(isActive),
          diverId: Value(diverId),
        ),
      );

  EquipmentComponent edge(String child) => EquipmentComponent(
    id: 'reg-$child',
    parentEquipmentId: 'reg',
    componentEquipmentId: child,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('lists the parts an attach would still write, whatever their '
      'owner', () async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'other',
            name: 'other',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await seed('fitted');
    await seed('spare', status: 'spare');
    await seed('sold', status: 'sold');
    await seed('borrowed', diverId: 'other');
    await seed('retired', status: 'retired');
    await seed('lost', status: 'lost');
    await seed('shelved', isActive: false);

    final container = ProviderContainer(
      overrides: [
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.fromRows([
            for (final id in [
              'fitted',
              'spare',
              'sold',
              'borrowed',
              'retired',
              'lost',
              'shelved',
              'deleted',
            ])
              edge(id),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(activeComponentIdsProvider.future), {
      'fitted',
      'spare',
      'sold',
      'borrowed',
    });
  });

  test('an empty template reads nothing', () async {
    final container = ProviderContainer(
      overrides: [
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.empty,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(activeComponentIdsProvider.future), isEmpty);
  });
}
