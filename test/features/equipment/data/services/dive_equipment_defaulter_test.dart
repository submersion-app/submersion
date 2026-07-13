import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentSetRepository sets;
  late DiveEquipmentDefaulter defaulter;

  setUp(() async {
    db = await setUpTestDatabase();
    // This test exercises junction writes (dive_equipment) without building
    // full Dives/Equipment fixtures; relax FK enforcement for it.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    sets = EquipmentSetRepository();
    defaulter = DiveEquipmentDefaulter();
  });
  tearDown(tearDownTestDatabase);

  EquipmentSet setWith(
    String id,
    List<String> equipmentIds, {
    bool isDefault = false,
  }) => EquipmentSet(
    id: id,
    diverId: 'd1',
    name: id,
    equipmentIds: equipmentIds,
    isDefault: isDefault,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  EquipmentSetGeofence geofence(String id, String setId) =>
      EquipmentSetGeofence(
        id: id,
        setId: setId,
        latitude: 36.62,
        longitude: -121.90,
        radiusMeters: 25000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.map((r) => r.equipmentId).toSet();
  }

  test('applies the default set to a dive with no equipment', () async {
    await sets.createSet(setWith('def', ['e1', 'e2'], isDefault: true));
    await sets.setAsDefault('def', diverId: 'd1');

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isTrue);
    expect(await equipmentOn('dive1'), {'e1', 'e2'});
  });

  test('never overwrites a dive that already has equipment', () async {
    await sets.createSet(setWith('def', ['e1'], isDefault: true));
    await sets.setAsDefault('def', diverId: 'd1');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'dive2',
            equipmentId: 'existing',
          ),
        );

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive2',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isFalse);
    expect(await equipmentOn('dive2'), {'existing'});
  });

  test('a matching geofence beats the default (entry GPS)', () async {
    await sets.createSet(setWith('def', ['warm'], isDefault: true));
    await sets.setAsDefault('def', diverId: 'd1');
    await sets.createSet(setWith('cold', ['drysuit']));
    await sets.addGeofence(geofence('g1', 'cold'));

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive3',
      diverId: 'd1',
      divePoints: const [GeoPoint(36.62, -121.90)],
    );

    expect(applied, isTrue);
    expect(await equipmentOn('dive3'), {'drysuit'});
  });

  test('skips an owner-less dive rather than crossing diver scopes', () async {
    // A default set belongs to d1; a dive with no diver must NOT inherit it.
    await sets.createSet(setWith('def', ['e1'], isDefault: true));
    await sets.setAsDefault('def', diverId: 'd1');

    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'orphan',
      diverId: null,
      divePoints: const [],
    );

    expect(applied, isFalse);
    expect(await equipmentOn('orphan'), isEmpty);
  });

  test('returns false when the diver has no sets', () async {
    final applied = await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: 'dive-none',
      diverId: 'd1',
      divePoints: const [],
    );
    expect(applied, isFalse);
  });

  test('applyForImportedDive skips a dive with no diver', () async {
    await sets.createSet(setWith('def', ['e1'], isDefault: true));
    await sets.setAsDefault('def', diverId: 'd1');
    final dive = createTestDiveWithBottomTime(
      id: 'orphan-import',
    ).copyWith(entryLocation: const GeoPoint(36.62, -121.90));

    expect(await defaulter.applyForImportedDive(dive), isFalse);
  });

  test('applyForImportedDive uses the entry GPS fix', () async {
    await sets.createSet(setWith('cold', ['drysuit']));
    await sets.addGeofence(geofence('g1', 'cold'));
    final dive = createTestDiveWithBottomTime(
      id: 'dive-import',
    ).copyWith(diverId: 'd1', entryLocation: const GeoPoint(36.62, -121.90));

    final applied = await defaulter.applyForImportedDive(dive);

    expect(applied, isTrue);
    expect(await equipmentOn('dive-import'), {'drysuit'});
  });
}
