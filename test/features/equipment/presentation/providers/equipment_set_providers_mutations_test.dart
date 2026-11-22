import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

import '../../../../helpers/test_database.dart';

/// Drives [EquipmentSetListNotifier] against a real test database and
/// asserts that the geofence-hydrated [equipmentSetProvider] family and the
/// selection-inputs provider reflect each change (guarding the
/// cache-invalidation fixes).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    // The notifier writes with the validated diver id; seed it so scoping works.
    final db = DatabaseService.instance.database;
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

  EquipmentSet newSet(String id, String name) => EquipmentSet(
    id: id,
    diverId: 'd1',
    name: name,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  EquipmentSetGeofence fence(
    String id,
    String setId, {
    double radius = 20000,
  }) => EquipmentSetGeofence(
    id: id,
    setId: setId,
    label: 'Monterey',
    latitude: 36.62,
    longitude: -121.9,
    radiusMeters: radius,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  test('addSet then equipmentSetsProvider lists it', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));

    final sets = await c.read(equipmentSetsProvider.future);
    expect(sets.map((s) => s.id), contains('a'));
  });

  // A set page's sitting writes through the save service, past the
  // notifier; afterSittingSaved is what refreshes the caches it read.
  test(
    'after a sitting moves the default, the hydrated family shows it',
    () async {
      final c = makeContainer();
      final notifier = c.read(equipmentSetListNotifierProvider.notifier);
      final sets = EquipmentSetRepository();
      await notifier.addSet(newSet('a', 'A'));
      await notifier.addSet(newSet('b', 'B'));

      // Prime the hydrated caches so invalidation is observable.
      expect(
        (await c.read(equipmentSetProvider('a').future))!.isDefault,
        isFalse,
      );
      expect(
        (await c.read(equipmentSetProvider('b').future))!.isDefault,
        isFalse,
      );

      await sets.setAsDefault('a', diverId: 'd1');
      await notifier.afterSittingSaved('a');
      expect(
        (await c.read(equipmentSetProvider('a').future))!.isDefault,
        isTrue,
      );

      // Promoting b demotes a, whose page the sitting on b never named: the
      // whole family is read again.
      await sets.setAsDefault('b', diverId: 'd1');
      await notifier.afterSittingSaved('b');
      expect(
        (await c.read(equipmentSetProvider('a').future))!.isDefault,
        isFalse,
      );
      expect(
        (await c.read(equipmentSetProvider('b').future))!.isDefault,
        isTrue,
      );
    },
  );

  test('after a sitting changes its geofences, the set, its fences and the '
      'selection inputs show them', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    final sets = EquipmentSetRepository();
    await notifier.addSet(newSet('a', 'A'));

    // Prime the hydrated caches (geofences empty).
    expect(
      (await c.read(equipmentSetProvider('a').future))!.geofences,
      isEmpty,
    );
    expect(await c.read(equipmentSetGeofencesProvider('a').future), isEmpty);
    expect(
      (await c.read(equipmentSetSelectionInputsProvider.future)).geofences,
      isEmpty,
    );

    await sets.addGeofence(fence('g1', 'a'));
    await notifier.afterSittingSaved('a');
    expect(
      (await c.read(equipmentSetProvider('a').future))!.geofences,
      hasLength(1),
    );
    expect(
      (await c.read(equipmentSetGeofencesProvider('a').future)).single.id,
      'g1',
    );
    expect(
      (await c.read(
        equipmentSetSelectionInputsProvider.future,
      )).geofences.single.id,
      'g1',
    );

    await sets.removeGeofence('g1');
    await notifier.afterSittingSaved('a');
    expect(
      (await c.read(equipmentSetProvider('a').future))!.geofences,
      isEmpty,
    );
  });

  test('selection inputs bundle carries sets and their geofences', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));
    await EquipmentSetRepository().addGeofence(fence('g1', 'a'));

    final inputs = await c.read(equipmentSetSelectionInputsProvider.future);
    expect(inputs.sets.map((s) => s.id), contains('a'));
    expect(inputs.geofences.map((g) => g.id), contains('g1'));
  });

  test('equipmentSetGeofencesProvider returns fences for a set', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));
    await EquipmentSetRepository().addGeofence(fence('g1', 'a'));

    final fences = await c.read(equipmentSetGeofencesProvider('a').future);
    expect(fences.map((g) => g.id), contains('g1'));
  });

  test('deleteSet removes it from the list', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));
    await notifier.deleteSet('a');

    final sets = await c.read(equipmentSetsProvider.future);
    expect(sets.map((s) => s.id), isNot(contains('a')));
  });
}
