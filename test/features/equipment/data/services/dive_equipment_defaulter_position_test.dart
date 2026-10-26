import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3704: a dive positioned from a GPS track after it was created gets
/// the set its position calls for, as it would have had the position been
/// known when the dive was written.
void main() {
  late AppDatabase db;
  late EquipmentSetRepository sets;
  late DiveEquipmentDefaulter defaulter;

  const inFence = GeoPoint(36.62, -121.90);
  const outsideFence = GeoPoint(10, 10);

  setUp(() async {
    db = await setUpTestDatabase();
    // Junction writes without a full Dive fixture, as in the sibling tests.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    sets = EquipmentSetRepository();
    defaulter = DiveEquipmentDefaulter();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['warm', 'drysuit', 'computer', 'transmitter']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    // The default set is for warm water; a geofenced one for the cold coast.
    // The computer is in both.
    await sets.createSet(
      EquipmentSet(
        id: 'def',
        diverId: 'd1',
        name: 'Warm',
        equipmentIds: const ['warm', 'computer'],
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await sets.setAsDefault('def', diverId: 'd1');
    await sets.createSet(
      EquipmentSet(
        id: 'cold',
        diverId: 'd1',
        name: 'Cold',
        equipmentIds: const ['drysuit', 'computer'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await sets.addGeofence(
      EquipmentSetGeofence(
        id: 'g1',
        setId: 'cold',
        latitude: inFence.latitude,
        longitude: inFence.longitude,
        radiusMeters: 25000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<Map<String, String?>> gearOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return {for (final r in rows) r.equipmentId: r.viaSetId};
  }

  /// What creating the dive with no position did: the default set.
  Future<void> createdWithoutPosition(String diveId) async {
    await defaulter.applyDefaultEquipmentIfEmpty(
      diveId: diveId,
      diverId: 'd1',
      divePoints: const [],
    );
  }

  Future<bool> positioned(
    String diveId,
    GeoPoint at, {
    bool replaceDefault = true,
  }) => defaulter.applyForNewPosition(
    diveId: diveId,
    diverId: 'd1',
    divePoints: [at],
    replaceDefault: replaceDefault,
  );

  test(
    'a dive with no gear takes the geofenced set for its new position',
    () async {
      expect(await positioned('dive', inFence, replaceDefault: false), isTrue);

      expect(await gearOn('dive'), {'drysuit': 'cold', 'computer': 'cold'});
    },
  );

  test('the default set applied without a position gives way to the '
      'geofenced one, keeping the gear both share', () async {
    await createdWithoutPosition('dive');
    expect(await gearOn('dive'), {'warm': 'def', 'computer': 'def'});

    expect(await positioned('dive', inFence), isTrue);

    expect(await gearOn('dive'), {'drysuit': 'cold', 'computer': 'cold'});
  });

  test('gear added another way stays through the swap', () async {
    await createdWithoutPosition('dive');
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'dive',
            equipmentId: 'transmitter',
          ),
        );

    expect(await positioned('dive', inFence), isTrue);

    expect(await gearOn('dive'), {
      'drysuit': 'cold',
      'computer': 'cold',
      'transmitter': null,
    });
  });

  test('without replaceDefault the default set stays', () async {
    await createdWithoutPosition('dive');

    expect(await positioned('dive', inFence, replaceDefault: false), isFalse);

    expect(await gearOn('dive'), {'warm': 'def', 'computer': 'def'});
  });

  test('a position in no geofence keeps the default set', () async {
    await createdWithoutPosition('dive');

    expect(await positioned('dive', outsideFence), isFalse);

    expect(await gearOn('dive'), {'warm': 'def', 'computer': 'def'});
  });

  test('gear from a set other than the default is never touched', () async {
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'dive',
            equipmentId: 'warm',
            viaSetId: const Value('other'),
          ),
        );

    expect(await positioned('dive', inFence), isFalse);

    expect(await gearOn('dive'), {'warm': 'other'});
  });

  test('a download no set reached gets the set its position calls for '
      'beside the gear it brought', () async {
    // The computer's own equipment entry, added after the defaulter ran.
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'dive',
            equipmentId: 'transmitter',
          ),
        );

    expect(await positioned('dive', inFence), isTrue);

    expect(await gearOn('dive'), {
      'transmitter': null,
      'drysuit': 'cold',
      'computer': 'cold',
    });
  });

  test('a file import\'s own gear with no set on it is left alone', () async {
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: 'dive',
            equipmentId: 'transmitter',
          ),
        );

    expect(await positioned('dive', inFence, replaceDefault: false), isFalse);

    expect(await gearOn('dive'), {'transmitter': null});
  });

  test('an owner-less dive is skipped', () async {
    expect(
      await defaulter.applyForNewPosition(
        diveId: 'dive',
        diverId: null,
        divePoints: const [inFence],
        replaceDefault: true,
      ),
      isFalse,
    );
    expect(await gearOn('dive'), isEmpty);
  });
}
