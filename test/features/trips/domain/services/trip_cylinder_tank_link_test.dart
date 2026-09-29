import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';

void main() {
  final t0 = DateTime.utc(2026, 3, 9, 7);

  TripCylinder slot(
    String id, {
    int order = 0,
    double? volume = 11.1,
    double? workingPressure = 207,
    String? presetName = 'al80',
    TankMaterial? material = TankMaterial.aluminum,
  }) => TripCylinder(
    id: id,
    tripId: 't1',
    label: 'Truck $id',
    volume: volume,
    workingPressure: workingPressure,
    material: material,
    presetName: presetName,
    sortOrder: order,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderState filled(
    TripCylinder c, {
    double pressure = 200,
    double o2 = 32,
    int minutes = 0,
  }) => foldCylinderState(
    cylinder: c,
    events: [
      TripCylinderEvent(
        id: 'f-${c.id}',
        tripCylinderId: c.id,
        kind: TripCylinderEventKind.fill,
        occurredAt: t0.add(Duration(minutes: minutes)),
        pressure: pressure,
        o2Percent: o2,
        createdAt: t0,
        updatedAt: t0,
      ),
    ],
    uses: const [],
  );

  const air = DiveTank(
    id: 'k1',
    volume: 12,
    workingPressure: 232,
    startPressure: 200,
    endPressure: 50,
    presetName: 'steel12',
  );

  group('tankFromTripCylinder', () {
    test('links and fills mix, start pressure and specs from the slot', () {
      final t = tankFromTripCylinder(air, filled(slot('a'), pressure: 205));
      expect(t.tripCylinderId, 'a');
      expect(t.gasMix.o2, 32);
      expect(t.startPressure, 205);
      expect(t.volume, 11.1);
      expect(t.workingPressure, 207);
      expect(t.material, TankMaterial.aluminum);
      expect(t.presetName, 'al80');
      // The end pressure is the diver's to log.
      expect(t.endPressure, 50);
    });

    test('keeps the tank\'s own values where the slot knows nothing', () {
      final bare = foldCylinderState(
        cylinder: slot(
          'b',
          volume: null,
          workingPressure: null,
          presetName: null,
        ),
        events: const [],
        uses: const [],
      );
      final t = tankFromTripCylinder(air, bare);
      expect(t.tripCylinderId, 'b');
      expect(t.gasMix, air.gasMix);
      expect(t.startPressure, 200);
      expect(t.volume, 12);
      expect(t.workingPressure, 232);
      expect(t.presetName, 'steel12');
    });

    test('a slot with specs but no preset clears the tank\'s preset', () {
      final t = tankFromTripCylinder(air, filled(slot('c', presetName: null)));
      expect(t.volume, 11.1);
      expect(t.presetName, isNull);
    });
  });

  test('a slot with specs but no material clears the tank\'s material', () {
    final steel = air.copyWith(material: TankMaterial.steel);
    final t = tankFromTripCylinder(
      steel,
      filled(slot('m', presetName: null, material: null)),
    );
    expect(t.volume, 11.1);
    expect(t.material, isNull);
  });

  group('suggestTripCylindersForTanks', () {
    test('links each eligible tank to a full slot and reports it', () {
      final r = suggestTripCylindersForTanks(
        tanks: [air.copyWith(gasMix: const GasMix(o2: 32))],
        states: [filled(slot('a'))],
        eligibleTankIds: {'k1'},
      );
      expect(r.tanks.single.tripCylinderId, 'a');
      expect(r.suggested, {'k1'});
    });

    test('siblings never share a suggestion', () {
      final r = suggestTripCylindersForTanks(
        tanks: [
          air,
          air.copyWith(id: 'k2'),
        ],
        states: [filled(slot('a'))],
        eligibleTankIds: {'k1', 'k2'},
      );
      expect(r.tanks[0].tripCylinderId, 'a');
      expect(r.tanks[1].tripCylinderId, isNull);
      expect(r.suggested, {'k1'});
    });

    test('a slot another tank already holds is never offered', () {
      final r = suggestTripCylindersForTanks(
        tanks: [
          air.copyWith(id: 'k0', tripCylinderId: 'a'),
          air,
        ],
        states: [filled(slot('a')), filled(slot('b', order: 1), minutes: 5)],
        eligibleTankIds: {'k1'},
      );
      expect(r.tanks[1].tripCylinderId, 'b');
    });

    test('ineligible and already linked tanks are left alone', () {
      final r = suggestTripCylindersForTanks(
        tanks: [
          air,
          air.copyWith(id: 'k2', tripCylinderId: 'x'),
        ],
        states: [filled(slot('a'))],
        eligibleTankIds: {'k2'},
      );
      expect(r.tanks[0].tripCylinderId, isNull);
      expect(r.tanks[1].tripCylinderId, 'x');
      expect(r.suggested, isEmpty);
    });

    test('nothing full, nothing suggested', () {
      final r = suggestTripCylindersForTanks(
        tanks: [air],
        states: [filled(slot('a'), pressure: 40)],
        eligibleTankIds: {'k1'},
      );
      expect(r.tanks.single.tripCylinderId, isNull);
      expect(r.suggested, isEmpty);
    });
  });
}
