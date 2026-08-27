import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

void main() {
  EquipmentSetGeofence fence(String id) => EquipmentSetGeofence(
    id: id,
    setId: 's1',
    latitude: 36.62,
    longitude: -121.9,
    radiusMeters: 20000,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  EquipmentSet base({List<EquipmentSetGeofence> geofences = const []}) =>
      EquipmentSet(
        id: 's1',
        name: 'Cold Water',
        geofences: geofences,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  test('sets differing only by geofences are not equal', () {
    // geofences is part of props, so a hydrated set with fences must not
    // compare equal to the same set without them (otherwise Riverpod would
    // suppress the state update that surfaces a newly-added fence).
    expect(base(geofences: [fence('g1')]), isNot(equals(base())));
  });

  test('sets with identical geofences are equal', () {
    expect(
      base(geofences: [fence('g1')]),
      equals(base(geofences: [fence('g1')])),
    );
  });

  test('copyWith carries geofences and isDefault', () {
    final updated = base().copyWith(isDefault: true, geofences: [fence('g1')]);
    expect(updated.isDefault, isTrue);
    expect(updated.geofences, hasLength(1));
  });
}
