import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentSetRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentSetRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['d1', 'd2']) {
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
  });

  tearDown(tearDownTestDatabase);

  EquipmentSet newSet(String id, String name, {String? diverId}) =>
      EquipmentSet(
        id: id,
        diverId: diverId,
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  test('setAsDefault flips exactly one default within a diver', () async {
    await repo.createSet(newSet('a', 'A', diverId: 'd1'));
    await repo.createSet(newSet('b', 'B', diverId: 'd1'));

    await repo.setAsDefault('a', diverId: 'd1');
    expect((await repo.getSetById('a'))!.isDefault, isTrue);
    expect((await repo.getSetById('b'))!.isDefault, isFalse);

    await repo.setAsDefault('b', diverId: 'd1');
    expect((await repo.getSetById('a'))!.isDefault, isFalse);
    expect((await repo.getSetById('b'))!.isDefault, isTrue);
  });

  test('default is independent across divers', () async {
    await repo.createSet(newSet('a', 'A', diverId: 'd1'));
    await repo.createSet(newSet('z', 'Z', diverId: 'd2'));
    await repo.setAsDefault('a', diverId: 'd1');
    await repo.setAsDefault('z', diverId: 'd2');
    expect((await repo.getSetById('a'))!.isDefault, isTrue);
    expect((await repo.getSetById('z'))!.isDefault, isTrue);
  });

  test('clearDefault leaves the diver with no default', () async {
    await repo.createSet(newSet('a', 'A', diverId: 'd1'));
    await repo.setAsDefault('a', diverId: 'd1');
    expect((await repo.getSetById('a'))!.isDefault, isTrue);

    await repo.clearDefault('a');
    expect((await repo.getSetById('a'))!.isDefault, isFalse);
  });

  test('geofence CRUD round-trips through the set', () async {
    await repo.createSet(newSet('a', 'A', diverId: 'd1'));
    final fence = EquipmentSetGeofence(
      id: 'g1',
      setId: 'a',
      label: 'Monterey',
      latitude: 36.62,
      longitude: -121.9,
      radiusMeters: 24000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repo.addGeofence(fence);
    expect(await repo.getGeofencesForSet('a'), hasLength(1));

    await repo.updateGeofence(fence.copyWith(radiusMeters: 30000));
    expect((await repo.getGeofencesForSet('a')).first.radiusMeters, 30000);

    final withGeofences = await repo.getSetById('a', includeGeofences: true);
    expect(withGeofences!.geofences, hasLength(1));

    await repo.removeGeofence('g1');
    expect(await repo.getGeofencesForSet('a'), isEmpty);
  });

  test(
    'deleteSet tombstones its geofences (cascade emits no tombstone)',
    () async {
      await repo.createSet(newSet('a', 'A', diverId: 'd1'));
      await repo.addGeofence(
        EquipmentSetGeofence(
          id: 'g1',
          setId: 'a',
          latitude: 36.62,
          longitude: -121.9,
          radiusMeters: 24000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repo.deleteSet('a');

      // The child row is gone locally...
      expect(await repo.getGeofencesForSet('a'), isEmpty);
      // ...and both the set and the geofence carry deletion-log tombstones, so a
      // peer will not resurrect the geofence over the cascade.
      final tombstones = await db.select(db.deletionLog).get();
      final byType = {for (final t in tombstones) t.entityType: t.recordId};
      expect(byType['equipmentSets'], 'a');
      expect(
        tombstones.any(
          (t) => t.entityType == 'equipmentSetGeofences' && t.recordId == 'g1',
        ),
        isTrue,
      );
    },
  );
}
