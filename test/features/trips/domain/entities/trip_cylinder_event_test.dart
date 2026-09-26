import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

void main() {
  final at = DateTime.utc(2026, 3, 9, 8, 15);

  TripCylinderEvent fill({
    double? o2 = 32,
    double? he,
    double? analyzedO2,
    double? analyzedHe,
  }) => TripCylinderEvent(
    id: 'e1',
    tripCylinderId: 'c1',
    kind: TripCylinderEventKind.fill,
    occurredAt: at,
    pressure: 200,
    o2Percent: o2,
    hePercent: he,
    analyzedO2: analyzedO2,
    analyzedHe: analyzedHe,
    createdAt: at,
    updatedAt: at,
  );

  group('kind parsing', () {
    test('known names round-trip', () {
      expect(tripCylinderEventKindFromName('fill'), TripCylinderEventKind.fill);
      expect(
        tripCylinderEventKindFromName('adjustment'),
        TripCylinderEventKind.adjustment,
      );
    });

    test('an unknown or missing name is an adjustment, never a throw', () {
      // A newer peer may add a kind this build does not know.
      expect(
        tripCylinderEventKindFromName('swap'),
        TripCylinderEventKind.adjustment,
      );
      expect(
        tripCylinderEventKindFromName(null),
        TripCylinderEventKind.adjustment,
      );
    });
  });

  group('mix getters', () {
    test('analyzed wins over ordered', () {
      final e = fill(o2: 32, analyzedO2: 31.6);
      expect(e.orderedMix!.o2, 32);
      expect(e.analyzedMix!.o2, 31.6);
      expect(e.effectiveMix!.o2, 31.6);
    });

    test('ordered stands in when nothing was analyzed', () {
      final e = fill(o2: 36);
      expect(e.analyzedMix, isNull);
      expect(e.effectiveMix!.o2, 36);
      expect(e.effectiveMix!.he, 0);
    });

    test('no mix at all yields null', () {
      expect(fill(o2: null).effectiveMix, isNull);
    });

    test('helium rides along with each reading', () {
      final e = fill(o2: 21, he: 35, analyzedO2: 20.5, analyzedHe: 34);
      expect(e.orderedMix!.he, 35);
      expect(e.analyzedMix!.he, 34);
    });
  });

  test('copyWith can clear a nullable field', () {
    final cleared = fill(analyzedO2: 31.6).copyWith(analyzedO2: null);
    expect(cleared.analyzedO2, isNull);
    expect(cleared.o2Percent, 32);
  });

  test('the wall-clock helper keeps the local reading and stamps it UTC', () {
    final local = DateTime(2026, 3, 9, 8, 15, 30);
    final wall = tripCylinderWallClock(local);
    expect(wall.isUtc, isTrue);
    expect(wall, DateTime.utc(2026, 3, 9, 8, 15, 30));
  });

  test('a slot copies with cleared specs', () {
    final slot = TripCylinder(
      id: 'c1',
      tripId: 't1',
      label: 'Truck 1',
      volume: 11.1,
      workingPressure: 207,
      material: TankMaterial.aluminum,
      createdAt: at,
      updatedAt: at,
    );
    final bare = slot.copyWith(volume: null, material: null);
    expect(bare.volume, isNull);
    expect(bare.material, isNull);
    expect(bare.workingPressure, 207);
    expect(bare, isNot(equals(slot)));
    expect(slot.copyWith(), slot);
  });
}
