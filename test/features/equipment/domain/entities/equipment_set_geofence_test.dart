import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

void main() {
  EquipmentSetGeofence make() => EquipmentSetGeofence(
    id: 'g1',
    setId: 's1',
    label: 'Monterey',
    latitude: 36.62,
    longitude: -121.9,
    radiusMeters: 24000,
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  test('center exposes a GeoPoint from lat/lng', () {
    expect(make().center, const GeoPoint(36.62, -121.9));
  });

  test('copyWith overrides only provided fields and is equatable', () {
    final a = make();
    final b = a.copyWith(radiusMeters: 30000);
    expect(b.radiusMeters, 30000);
    expect(b.copyWith(radiusMeters: 24000), a);
  });
}
