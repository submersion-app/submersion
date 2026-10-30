import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_database.dart';

/// The item page's Dive Time row sums the dives its Dives row counts
/// (issue #3550): one set of dives behind both rows, whichever way each is
/// linked, with the length the exposure totals read.
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;
  const t = 1000;

  Future<void> addDive(
    String id, {
    String diver = 'owner',
    int? runtime,
    int? bottomTime,
    bool excludedFromStats = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: t,
          createdAt: t,
          updatedAt: t,
        ).copyWith(
          diverId: Value(diver),
          runtime: Value(runtime),
          bottomTime: Value(bottomTime),
          excludedFromStats: Value(excludedFromStats),
        ),
      );

  Future<void> addGearLink(String diveId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: 'item'),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    for (final id in ['owner', 'buddy']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'item',
            name: 'Item',
            type: 'regulator',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('sums the runtime of the dives the item is on', () async {
    await addDive('d1', runtime: 3000);
    await addDive('d2', runtime: 1800);
    await addDive('unlinked', runtime: 9000);
    await addGearLink('d1');
    await addGearLink('d2');

    expect(await repo.getDiveTimeForEquipment('item'), 4800);
  });

  test('an item on no dives has no time', () async {
    expect(await repo.getDiveTimeForEquipment('item'), 0);
  });

  test('reaches a dive through every link the Dives row counts', () async {
    await addDive('direct', runtime: 100);
    await addGearLink('direct');
    await addDive('cylinder', runtime: 200);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k1',
            diveId: 'cylinder',
          ).copyWith(equipmentId: const Value('item')),
        );
    await addDive('first-regulator', runtime: 400);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k2',
            diveId: 'first-regulator',
          ).copyWith(regulatorEquipmentId: const Value('item')),
        );
    await addDive('extra-regulator', runtime: 800);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k3',
            diveId: 'extra-regulator',
          ).copyWith(extraRegulatorIds: const Value('["item"]')),
        );

    expect(await repo.getDiveCountForEquipment('item'), 4);
    expect(await repo.getDiveTimeForEquipment('item'), 1500);
  });

  test('a dive linked more than one way adds its time once', () async {
    await addDive('d1', runtime: 3000);
    await addGearLink('d1');
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 'k1', diveId: 'd1').copyWith(
            equipmentId: const Value('item'),
            regulatorEquipmentId: const Value('item'),
            extraRegulatorIds: const Value('["item"]'),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k2',
            diveId: 'd1',
          ).copyWith(equipmentId: const Value('item')),
        );

    expect(await repo.getDiveTimeForEquipment('item'), 3000);
  });

  test('with a diver, only that diver\'s dives; without one, all', () async {
    await addDive('mine', runtime: 3000);
    await addDive('theirs', diver: 'buddy', runtime: 1200);
    await addGearLink('mine');
    await addGearLink('theirs');

    expect(await repo.getDiveTimeForEquipment('item', diverId: 'owner'), 3000);
    expect(await repo.getDiveTimeForEquipment('item', diverId: 'buddy'), 1200);
    expect(await repo.getDiveTimeForEquipment('item'), 4200);
  });

  test('a dive with no runtime falls back to its bottom time', () async {
    await addDive('null-runtime', bottomTime: 600);
    await addDive('zero-runtime', runtime: 0, bottomTime: 900);
    await addGearLink('null-runtime');
    await addGearLink('zero-runtime');

    expect(await repo.getDiveTimeForEquipment('item'), 1500);
  });

  test('runtime wins over a bottom time when both exist', () async {
    await addDive('d1', runtime: 3000, bottomTime: 2400);
    await addGearLink('d1');

    expect(await repo.getDiveTimeForEquipment('item'), 3000);
  });

  test('a dive with neither length adds nothing', () async {
    await addDive('blank');
    await addDive('zeros', runtime: 0, bottomTime: 0);
    await addDive('timed', runtime: 1200);
    for (final id in ['blank', 'zeros', 'timed']) {
      await addGearLink(id);
    }

    expect(await repo.getDiveCountForEquipment('item'), 3);
    expect(await repo.getDiveTimeForEquipment('item'), 1200);
  });

  test('a dive excluded from statistics still counts', () async {
    await addDive('excluded', runtime: 2400, excludedFromStats: true);
    await addGearLink('excluded');

    expect(await repo.getDiveTimeForEquipment('item'), 2400);
  });

  test('the Dive Time row refreshes when a tank link is added', () async {
    await addDive('d1', runtime: 3000);
    await addGearLink('d1');
    await addDive('d2', runtime: 1800);
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'owner'),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(equipmentDiveTimeProvider('item'), (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(equipmentDiveTimeProvider('item').future),
      3000,
    );

    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k1',
            diveId: 'd2',
          ).copyWith(equipmentId: const Value('item')),
        );
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(
      await container.read(equipmentDiveTimeProvider('item').future),
      4800,
    );
  });

  test('the row reads only the active diver\'s dives', () async {
    await addDive('mine', runtime: 3000);
    await addDive('theirs', diver: 'buddy', runtime: 1200);
    await addGearLink('mine');
    await addGearLink('theirs');
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'owner'),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(equipmentDiveTimeProvider('item').future),
      3000,
    );
  });
}
