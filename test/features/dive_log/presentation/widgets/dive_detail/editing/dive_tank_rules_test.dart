import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Cylinders in a sitting: added, removed and linked to the trip's slots
/// (issue #4527, plan 5).
void main() {
  final t0 = DateTime.utc(2026, 3, 9, 7);
  final trip = Trip(
    id: 'trip',
    name: 'Red Sea',
    startDate: t0,
    endDate: t0.add(const Duration(days: 6)),
    createdAt: t0,
    updatedAt: t0,
  );
  final otherTrip = Trip(
    id: 'other',
    name: 'Cozumel',
    startDate: t0,
    endDate: t0.add(const Duration(days: 6)),
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderState filled(String id) => foldCylinderState(
    cylinder: TripCylinder(
      id: id,
      tripId: 'trip',
      label: 'Truck $id',
      volume: 11.1,
      workingPressure: 207,
      sortOrder: 0,
      createdAt: t0,
      updatedAt: t0,
    ),
    events: [
      TripCylinderEvent(
        id: 'f-$id',
        tripCylinderId: id,
        kind: TripCylinderEventKind.fill,
        occurredAt: t0,
        pressure: 200,
        o2Percent: 32,
        createdAt: t0,
        updatedAt: t0,
      ),
    ],
    uses: const [],
  );

  const stored = DiveTank(id: 'a', volume: 12, startPressure: 200);
  final dive = Dive(
    id: 'dive',
    dateTime: t0.add(const Duration(hours: 2)),
    tanks: const [stored],
    trip: trip,
    tripId: trip.id,
  );

  DiveTank added(String id, {int order = 1}) => DiveTank(
    id: id,
    volume: 12,
    startPressure: 200,
    role: TankRole.stage,
    order: order,
  );

  Future<List<TripCylinderState>> slots(String tripId, DateTime at) async =>
      tripId == 'trip' ? [filled('s1'), filled('s2')] : const [];

  group('newSittingTank', () {
    test('the first is back gas, sized by the settings', () {
      final t = newSittingTank(
        tanks: const [],
        preset: null,
        defaultVolume: 11.1,
        defaultStartPressure: 207,
      );
      expect(t.id, isNotEmpty);
      expect(
        (t.role, t.volume, t.startPressure, t.endPressure, t.gasMix, t.order),
        (TankRole.backGas, 11.1, 207.0, 50.0, const GasMix(), 0),
      );
    });

    test('a later one is a stage, sized by the preset', () {
      final preset = TankPresetEntity(
        id: 'p',
        name: 'al80',
        displayName: 'AL80',
        volumeLiters: 11.1,
        workingPressureBar: 207,
        material: TankMaterial.aluminum,
        description: '',
        sortOrder: 0,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      );
      final t = newSittingTank(
        tanks: const [stored],
        preset: preset,
        defaultVolume: 12,
        defaultStartPressure: 200,
      );
      expect(
        (t.role, t.volume, t.workingPressure, t.material, t.presetName),
        (TankRole.stage, 11.1, 207.0, TankMaterial.aluminum, 'al80'),
      );
      expect(t.order, 1);
    });
  });

  test('removing a cylinder renumbers the rest', () {
    final s = EditSession(
      dive.copyWith(tanks: [stored, added('b'), added('c', order: 2)]),
    );
    removeSittingTank(s, 'b');
    expect(
      [for (final t in s.working.tanks) (t.id, t.order)],
      [('a', 0), ('c', 1)],
    );
  });

  test('setTanks leaves the order of untouched cylinders alone', () {
    final gapped = dive.copyWith(tanks: const [DiveTank(id: 'a', order: 3)]);
    final s = EditSession(gapped);
    setTanks(s, const [DiveTank(id: 'a', order: 3, volume: 10)]);
    expect(s.working.tanks.single.order, 3);
  });

  group('trip slots', () {
    test('an added cylinder on a trip is suggested a slot; a stored one is '
        'not', () async {
      final s = EditSession(dive);
      setTanks(s, [stored, added('b')]);
      suggestTankSlots(s, readSlots: slots);
      await s.settled();
      final byId = {for (final t in s.working.tanks) t.id: t};
      expect(byId['a']!.tripCylinderId, isNull);
      expect(byId['b']!.tripCylinderId, isNotNull);
      expect(suggestedTankIds(s), {'b'});
    });

    test('a declined suggestion is not made again', () async {
      final s = EditSession(dive);
      setTanks(s, [stored, added('b')]);
      tankSlotChosen(s, 'b', none: true);
      suggestTankSlots(s, readSlots: slots);
      await s.settled();
      expect(s.working.tanks.last.tripCylinderId, isNull);
    });

    test('a slot the diver chose is no longer a suggestion', () async {
      final s = EditSession(dive);
      setTanks(s, [stored, added('b')]);
      suggestTankSlots(s, readSlots: slots);
      await s.settled();
      tankSlotChosen(s, 'b', none: false);
      expect(suggestedTankIds(s), isEmpty);
    });

    test('a trip change clears every link and suggests again', () async {
      final linked = dive.copyWith(
        tanks: [stored.copyWith(tripCylinderId: 's1')],
      );
      final s = EditSession(linked);
      setTanks(s, [...s.working.tanks, added('b')]);
      s.set(diveTripField, otherTrip);
      tanksAfterTripChange(s, readSlots: slots);
      await s.settled();
      expect([
        for (final t in s.working.tanks) t.tripCylinderId,
      ], everyElement(isNull));
    });

    test('a trip changed and changed back gives the stored cylinders their '
        'links back, so the card is unchanged', () async {
      final linked = dive.copyWith(
        tanks: [stored.copyWith(tripCylinderId: 's1')],
      );
      final s = EditSession(linked)..set(diveTripField, otherTrip);
      tanksAfterTripChange(s, readSlots: slots);
      s.set(diveTripField, trip);
      tanksAfterTripChange(s, readSlots: slots);
      await s.settled();
      expect(s.working.tanks.single.tripCylinderId, 's1');
      expect(s.changedCardIds, isEmpty);
    });

    test('clearing the trip clears the links and suggests nothing', () async {
      final linked = dive.copyWith(
        tanks: [stored.copyWith(tripCylinderId: 's1')],
      );
      var reads = 0;
      final s = EditSession(linked)..set(diveTripField, null);
      tanksAfterTripChange(
        s,
        readSlots: (id, at) async {
          reads++;
          return slots(id, at);
        },
      );
      await s.settled();
      expect(s.working.tanks.single.tripCylinderId, isNull);
      expect(reads, 0);
    });

    test('slots answering after the trip changed again are dropped', () async {
      final gate = Completer<List<TripCylinderState>>();
      final s = EditSession(dive);
      setTanks(s, [stored, added('b')]);
      suggestTankSlots(s, readSlots: (_, _) => gate.future);
      s.set(diveTripField, otherTrip);
      gate.complete([filled('s1')]);
      await s.settled();
      expect(s.working.tanks.last.tripCylinderId, isNull);
    });

    test('a read answering after the sitting ended sets nothing', () async {
      final gate = Completer<List<TripCylinderState>>();
      final s = EditSession(dive);
      setTanks(s, [stored, added('b')]);
      suggestTankSlots(s, readSlots: (_, _) => gate.future);
      s.dispose();
      gate.complete([filled('s1')]);
      await Future<void>.delayed(Duration.zero);
      expect(s.working.tanks.last.tripCylinderId, isNull);
    });
  });
}
