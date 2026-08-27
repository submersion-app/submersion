import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

import '../../../../helpers/test_database.dart';

/// The equipment-set providers must refresh when the gear they point at
/// changes, even when the write never touches [EquipmentSetListNotifier].
///
/// Issue #819: deleting a gear item cascades its `equipment_set_items` rows
/// away, but the cached [EquipmentSet] kept serving the dead id. The edit form
/// seeded its selection from that cache and the save died on the foreign key.
/// Deleting equipment also happens during a sync or an import, which bypass the
/// notifier entirely -- hence a table-change stream rather than hand-written
/// invalidations on the mutation paths.
void main() {
  late AppDatabase db;
  late EquipmentSetRepository setRepo;
  late EquipmentRepository equipmentRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    setRepo = EquipmentSetRepository();
    equipmentRepo = EquipmentRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
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
    for (final id in ['e1', 'e2', 'e3']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
    await setRepo.createSet(
      EquipmentSet(
        id: 's1',
        diverId: 'd1',
        name: 'My Equipment',
        equipmentIds: const ['e1', 'e2', 'e3'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Polls [read] until [settled], budgeting off the repository's debounce
  /// rather than a magic number.
  Future<T> pollUntil<T>(
    Future<T> Function() read,
    bool Function(T) settled,
  ) async {
    final deadline = DateTime.now().add(
      EquipmentSetRepository.changeTickDebounce * 20,
    );
    var value = await read();
    while (!settled(value) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      value = await read();
    }
    return value;
  }

  test('equipmentSetProvider drops a member deleted straight from the DB '
      '(sync scenario)', () async {
    final c = makeContainer();
    // An active listener keeps the provider -- and its table-change
    // subscription -- alive, mirroring a widget watching the set.
    final sub = c.listen(equipmentSetProvider('s1'), (_, _) {});
    addTearDown(sub.close);

    expect((await c.read(equipmentSetProvider('s1').future))!.equipmentIds, [
      'e1',
      'e2',
      'e3',
    ]);

    // No notifier involved: this is what a sync or an import does.
    await equipmentRepo.deleteEquipment('e2');

    final ids = await pollUntil(
      () async =>
          (await c.read(equipmentSetProvider('s1').future))!.equipmentIds,
      (v) => v.length == 2,
    );

    expect(
      ids,
      unorderedEquals(['e1', 'e3']),
      reason:
          'drift propagates the equipment ON DELETE CASCADE to '
          'equipment_set_items, so the set provider must re-read',
    );
  });

  test('equipmentSetProvider drops the hydrated item too', () async {
    final c = makeContainer();
    final sub = c.listen(equipmentSetProvider('s1'), (_, _) {});
    addTearDown(sub.close);

    expect(
      (await c.read(equipmentSetProvider('s1').future))!.items,
      hasLength(3),
    );

    await equipmentRepo.deleteEquipment('e2');

    final items = await pollUntil(
      () async => (await c.read(equipmentSetProvider('s1').future))!.items!,
      (v) => v.length == 2,
    );
    expect(items.map((e) => e.id), unorderedEquals(['e1', 'e3']));
  });

  test('equipmentSetProvider reflects a renamed member (rename does not '
      'cascade, so the equipment table is watched directly)', () async {
    final c = makeContainer();
    final sub = c.listen(equipmentSetProvider('s1'), (_, _) {});
    addTearDown(sub.close);

    expect(
      (await c.read(
        equipmentSetProvider('s1').future,
      ))!.items!.map((e) => e.name),
      contains('e2'),
    );

    await (db.update(db.equipment)..where((t) => t.id.equals('e2'))).write(
      const EquipmentCompanion(name: Value('Renamed BCD')),
    );

    final names = await pollUntil(
      () async => (await c.read(
        equipmentSetProvider('s1').future,
      ))!.items!.map((e) => e.name).toList(),
      (v) => v.contains('Renamed BCD'),
    );
    expect(names, contains('Renamed BCD'));
  });

  test('equipmentSetsProvider drops the member from the list view', () async {
    final c = makeContainer();
    final sub = c.listen(equipmentSetsProvider, (_, _) {});
    addTearDown(sub.close);

    expect((await c.read(equipmentSetsProvider.future)).single.itemCount, 3);

    await equipmentRepo.deleteEquipment('e2');

    final count = await pollUntil(
      () async => (await c.read(equipmentSetsProvider.future)).single.itemCount,
      (v) => v == 2,
    );
    expect(
      count,
      2,
      reason: 'the sets list renders itemCount off equipmentIds',
    );
  });

  test('equipmentSetWithItemsProvider shares the refreshed cache', () async {
    final c = makeContainer();
    final sub = c.listen(equipmentSetWithItemsProvider('s1'), (_, _) {});
    addTearDown(sub.close);

    expect(
      (await c.read(equipmentSetWithItemsProvider('s1').future))!.equipmentIds,
      hasLength(3),
    );

    await equipmentRepo.deleteEquipment('e2');

    final ids = await pollUntil(
      () async => (await c.read(
        equipmentSetWithItemsProvider('s1').future,
      ))!.equipmentIds,
      (v) => v.length == 2,
    );
    expect(
      ids,
      unorderedEquals(['e1', 'e3']),
      reason:
          'the picker sheet reads this provider; as an independent cache it '
          'was never invalidated by anything',
    );
  });

  test(
    'equipmentSetListNotifier refreshes its list on a gear delete',
    () async {
      final c = makeContainer();
      final sub = c.listen(equipmentSetListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      final counts = await pollUntil(
        () async => c
            .read(equipmentSetListNotifierProvider)
            .valueOrNull
            ?.map((s) => s.itemCount)
            .toList(),
        (v) => v != null && v.isNotEmpty,
      );
      expect(counts, [3]);

      await equipmentRepo.deleteEquipment('e2');

      final after = await pollUntil(
        () async => c
            .read(equipmentSetListNotifierProvider)
            .valueOrNull
            ?.map((s) => s.itemCount)
            .toList(),
        (v) => v != null && v.isNotEmpty && v.first == 2,
      );
      expect(after, [2]);
    },
  );
}
