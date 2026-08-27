import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';

EquipmentSet set(String id, {bool isDefault = false}) => EquipmentSet(
  id: id,
  name: id,
  isDefault: isDefault,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

EquipmentSetGeofence fence(
  String id,
  String setId,
  double lat,
  double lng,
  double radius,
) => EquipmentSetGeofence(
  id: id,
  setId: setId,
  latitude: lat,
  longitude: lng,
  radiusMeters: radius,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  const monterey = GeoPoint(36.62, -121.90); // ~ dive point
  final cold = set('cold');
  final warm = set('warm');
  final def = set('def', isDefault: true);

  test('returns null when nothing matches and no default', () {
    expect(
      EquipmentSetSelector.bestSetFor(
        divePoints: const [monterey],
        sets: [cold, warm],
        geofences: const [],
      ),
      isNull,
    );
  });

  test('falls back to the global default when no geofence matches', () {
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [monterey],
      sets: [cold, def],
      geofences: [fence('g', 'cold', 0, 0, 1000)], // far away
    );
    expect(result, def);
  });

  test('geofence match beats the global default', () {
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [monterey],
      sets: [cold, def],
      geofences: [fence('g', 'cold', 36.62, -121.90, 25000)],
    );
    expect(result, cold);
  });

  test('matches when ANY dive point is inside the fence', () {
    const elsewhere = GeoPoint(0, 0);
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [elsewhere, monterey], // exit fix lands in fence
      sets: [cold, def],
      geofences: [fence('g', 'cold', 36.62, -121.90, 25000)],
    );
    expect(result, cold);
  });

  test('overlapping fences resolve to nearest center', () {
    // cold centered exactly on the dive point (0 m); warm 10 km off but still
    // containing the point with a large radius. Nearest center wins.
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [monterey],
      sets: [cold, warm],
      geofences: [
        fence('gw', 'warm', 36.70, -121.90, 40000),
        fence('gc', 'cold', 36.62, -121.90, 40000),
      ],
    );
    expect(result, cold);
  });

  test('empty divePoints skips geofences and uses default', () {
    final result = EquipmentSetSelector.bestSetFor(
      divePoints: const [],
      sets: [cold, def],
      geofences: [fence('g', 'cold', 36.62, -121.90, 25000)],
    );
    expect(result, def);
  });

  test(
    'matchingGeofenceSet returns null when only the default would apply',
    () {
      expect(
        EquipmentSetSelector.matchingGeofenceSet(
          divePoints: const [monterey],
          sets: [cold, def],
          geofences: [fence('g', 'cold', 0, 0, 1000)], // far away
        ),
        isNull,
      );
    },
  );

  test('equidistant fences tie-break to the smaller (more specific) radius', () {
    // Both centered on the dive point (distance 0), so the tighter radius wins.
    final result = EquipmentSetSelector.matchingGeofenceSet(
      divePoints: const [monterey],
      sets: [cold, warm],
      geofences: [
        fence('gw', 'warm', 36.62, -121.90, 40000),
        fence('gc', 'cold', 36.62, -121.90, 10000),
      ],
    );
    expect(result, cold);
  });

  test('equidistant equal-radius fences tie-break by lexicographic setId', () {
    // Identical center and radius: deterministic winner is the smaller setId
    // ("cold" < "warm").
    final result = EquipmentSetSelector.matchingGeofenceSet(
      divePoints: const [monterey],
      sets: [cold, warm],
      geofences: [
        fence('gw', 'warm', 36.62, -121.90, 20000),
        fence('gc', 'cold', 36.62, -121.90, 20000),
      ],
    );
    expect(result, cold);
  });

  test('returns null when the matched fence has no set in the list', () {
    // Fence points at "ghost" but that set was not supplied.
    final result = EquipmentSetSelector.matchingGeofenceSet(
      divePoints: const [monterey],
      sets: [warm],
      geofences: [fence('g', 'ghost', 36.62, -121.90, 25000)],
    );
    expect(result, isNull);
  });
}
