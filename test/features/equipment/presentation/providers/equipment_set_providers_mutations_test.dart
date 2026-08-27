import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

import '../../../../helpers/test_database.dart';

/// Drives [EquipmentSetListNotifier] through its mutations against a real test
/// database and asserts that the geofence-hydrated [equipmentSetProvider]
/// family and the selection-inputs provider reflect each change (guarding the
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

  test('setAsDefault refreshes the hydrated set family badge', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));
    await notifier.addSet(newSet('b', 'B'));

    // Prime the hydrated caches so invalidation is observable.
    expect(
      (await c.read(equipmentSetProvider('a').future))!.isDefault,
      isFalse,
    );

    await notifier.setAsDefault('a');
    expect((await c.read(equipmentSetProvider('a').future))!.isDefault, isTrue);

    // Promoting b must demote a in the hydrated family (whole-family invalidate).
    await notifier.setAsDefault('b');
    expect(
      (await c.read(equipmentSetProvider('a').future))!.isDefault,
      isFalse,
    );
    expect((await c.read(equipmentSetProvider('b').future))!.isDefault, isTrue);
  });

  test('clearDefault refreshes the hydrated set family', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));
    await notifier.setAsDefault('a');
    expect((await c.read(equipmentSetProvider('a').future))!.isDefault, isTrue);

    await notifier.clearDefault('a');
    expect(
      (await c.read(equipmentSetProvider('a').future))!.isDefault,
      isFalse,
    );
  });

  test('geofence add/update/remove re-hydrate equipmentSetProvider', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));

    // Prime the hydrated cache (geofences empty).
    expect(
      (await c.read(equipmentSetProvider('a').future))!.geofences,
      isEmpty,
    );

    await notifier.addGeofence(fence('g1', 'a'));
    expect(
      (await c.read(equipmentSetProvider('a').future))!.geofences,
      hasLength(1),
    );

    await notifier.updateGeofence(fence('g1', 'a', radius: 55000));
    expect(
      (await c.read(
        equipmentSetProvider('a').future,
      ))!.geofences.first.radiusMeters,
      55000,
    );

    await notifier.removeGeofence('a', 'g1');
    expect(
      (await c.read(equipmentSetProvider('a').future))!.geofences,
      isEmpty,
    );
  });

  test('selection inputs bundle carries sets and their geofences', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));
    await notifier.addGeofence(fence('g1', 'a'));

    final inputs = await c.read(equipmentSetSelectionInputsProvider.future);
    expect(inputs.sets.map((s) => s.id), contains('a'));
    expect(inputs.geofences.map((g) => g.id), contains('g1'));
  });

  test('equipmentSetGeofencesProvider returns fences for a set', () async {
    final c = makeContainer();
    final notifier = c.read(equipmentSetListNotifierProvider.notifier);
    await notifier.addSet(newSet('a', 'A'));
    await notifier.addGeofence(fence('g1', 'a'));

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
