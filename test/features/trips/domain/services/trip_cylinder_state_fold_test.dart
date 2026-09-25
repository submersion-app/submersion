import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// Pure arithmetic over one slot's timeline. Every expectation here was
/// worked out by hand from the spec's rules before the fold existed.
void main() {
  final t0 = DateTime.utc(2026, 3, 9, 8, 0);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  final slot = TripCylinder(
    id: 'c1',
    tripId: 't1',
    label: 'Truck 1',
    volume: 11.1,
    workingPressure: 207,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent fill(
    int minutes, {
    String id = 'f',
    double? pressure = 200,
    double? o2 = 32,
    double? analyzedO2,
    String? label,
  }) => TripCylinderEvent(
    id: '$id$minutes',
    tripCylinderId: 'c1',
    kind: TripCylinderEventKind.fill,
    occurredAt: at(minutes),
    pressure: pressure,
    o2Percent: o2,
    analyzedO2: analyzedO2,
    bottleLabel: label,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent adjust(int minutes, {double? pressure, double? o2}) =>
      TripCylinderEvent(
        id: 'a$minutes',
        tripCylinderId: 'c1',
        kind: TripCylinderEventKind.adjustment,
        occurredAt: at(minutes),
        pressure: pressure,
        o2Percent: o2,
        createdAt: t0,
        updatedAt: t0,
      );

  TripCylinderTankUse dive(
    int minutes, {
    String diveId = 'd',
    String tankId = 'k',
    double? end = 60,
    double o2 = 32,
  }) => TripCylinderTankUse(
    tankId: '$tankId$minutes',
    diveId: '$diveId$minutes',
    entryTime: at(minutes),
    startPressure: 200,
    endPressure: end,
    gasMix: GasMix(o2: o2),
  );

  TripCylinderState fold({
    List<TripCylinderEvent> events = const [],
    List<TripCylinderTankUse> uses = const [],
  }) => foldCylinderState(cylinder: slot, events: events, uses: uses);

  group('foldCylinderState', () {
    test('an untouched slot is unknown and wears its own label', () {
      final s = fold();
      expect(s.status, TripCylinderStatus.unknown);
      expect(s.pressure, isNull);
      expect(s.mix, isNull);
      expect(s.bottleLabel, 'Truck 1');
      expect(s.lastFill, isNull);
      expect(s.lastEventAt, isNull);
      expect(s.linkedDiveCount, 0);
    });

    test(
      'a fill makes it full with the analyzed mix and the bottle number',
      () {
        final f = fill(0, analyzedO2: 31.6, label: '14');
        final s = fold(events: [f]);
        expect(s.status, TripCylinderStatus.full);
        expect(s.pressure, 200);
        expect(s.mix!.o2, 31.6);
        expect(s.bottleLabel, '14');
        expect(s.lastFill, f);
        expect(s.lastEventAt, at(0));
      },
    );

    test('a fill with no pressure reads as the working pressure', () {
      expect(fold(events: [fill(0, pressure: null)]).pressure, 207);
    });

    test('ordered mix stands in until something is analyzed', () {
      final s = fold(
        events: [fill(0, o2: 32), fill(60, o2: 36, analyzedO2: 35.8)],
      );
      expect(s.mix!.o2, 35.8);
      expect(fold(events: [fill(0, o2: 32)]).mix!.o2, 32);
    });

    test('a dive after the fill leaves it partial at the end pressure', () {
      final s = fold(events: [fill(0)], uses: [dive(60, end: 60, o2: 33)]);
      expect(s.status, TripCylinderStatus.partial);
      expect(s.pressure, 60);
      // The dive never changes the slot's mix; its own mix is its own truth.
      expect(s.mix!.o2, 32);
      expect(s.linkedDiveCount, 1);
      expect(s.lastEventAt, at(60));
    });

    test('a dive timestamped before the last fill does not spend it', () {
      // Tuesday's dive imported on Friday slots into Tuesday.
      final s = fold(events: [fill(120)], uses: [dive(60)]);
      expect(s.status, TripCylinderStatus.full);
      expect(s.pressure, 200);
    });

    test('on one instant the fill applies before the dive', () {
      final s = fold(events: [fill(60)], uses: [dive(60)]);
      expect(s.status, TripCylinderStatus.partial);
      expect(s.pressure, 60);
    });

    test('on one instant a correction applies after the dive', () {
      final s = fold(
        events: [fill(0), adjust(60, pressure: 0)],
        uses: [dive(60)],
      );
      expect(s.status, TripCylinderStatus.empty);
      expect(s.pressure, 0);
    });

    test('mark empty is empty', () {
      final s = fold(events: [fill(0), adjust(30, pressure: 0)]);
      expect(s.status, TripCylinderStatus.empty);
    });

    test('a dive ending at the empty line is empty', () {
      expect(
        fold(events: [fill(0)], uses: [dive(30, end: 50)]).status,
        TripCylinderStatus.empty,
      );
      expect(
        fold(events: [fill(0)], uses: [dive(30, end: 51)]).status,
        TripCylinderStatus.partial,
      );
    });

    test('a gauge reading near the working pressure is full', () {
      // 0.9 * 207 = 186.3
      expect(
        fold(events: [adjust(0, pressure: 190)]).status,
        TripCylinderStatus.full,
      );
      expect(
        fold(events: [adjust(0, pressure: 186)]).status,
        TripCylinderStatus.partial,
      );
    });

    test('a correction with no pressure changes nothing but the clock', () {
      // The bottle is still at its fill pressure, so it is still full.
      final s = fold(events: [fill(0), adjust(30)]);
      expect(s.pressure, 200);
      expect(s.status, TripCylinderStatus.full);
      expect(s.lastEventAt, at(30));
    });

    test('a correction can carry a mix', () {
      expect(
        fold(events: [fill(0), adjust(30, pressure: 150, o2: 30)]).mix!.o2,
        30,
      );
    });

    test(
      'a dive with no end pressure leaves the pressure unknown but used',
      () {
        final s = fold(events: [fill(0)], uses: [dive(60, end: null)]);
        expect(s.pressure, isNull);
        expect(s.status, TripCylinderStatus.partial);
      },
    );

    test('the bottle number carries until a fill names another', () {
      final s = fold(
        events: [
          fill(0, label: '14'),
          fill(60),
          fill(120, label: '7'),
        ],
      );
      expect(s.bottleLabel, '7');
      expect(
        fold(
          events: [
            fill(0, label: '14'),
            fill(60),
          ],
        ).bottleLabel,
        '14',
      );
      expect(
        fold(
          events: [
            fill(0, label: '14'),
            fill(60, label: ''),
          ],
        ).bottleLabel,
        '14',
      );
    });

    test('linked dives are counted once per dive, not per tank', () {
      final twoTanks = [
        TripCylinderTankUse(
          tankId: 'k1',
          diveId: 'd1',
          entryTime: at(60),
          endPressure: 100,
        ),
        TripCylinderTankUse(
          tankId: 'k2',
          diveId: 'd1',
          entryTime: at(60),
          endPressure: 90,
        ),
        dive(120),
      ];
      expect(fold(events: [fill(0)], uses: twoTanks).linkedDiveCount, 2);
    });

    test('a second fill after a dive restores full', () {
      final s = fold(events: [fill(0), fill(120)], uses: [dive(60)]);
      expect(s.status, TripCylinderStatus.full);
      expect(s.pressure, 200);
      expect(s.lastFill!.id, 'f120');
    });
  });

  group('suggestTripCylinder', () {
    TripCylinderState state(
      String id, {
      TripCylinderStatus status = TripCylinderStatus.full,
      double? o2 = 32,
      int? filledAt = 0,
      int sortOrder = 0,
    }) => TripCylinderState(
      cylinder: slot.copyWith(id: id, sortOrder: sortOrder),
      pressure: 200,
      mix: o2 == null ? null : GasMix(o2: o2),
      bottleLabel: id,
      status: status,
      lastFill: filledAt == null
          ? null
          : fill(filledAt, id: id).copyWith(tripCylinderId: id),
      lastEventAt: at(filledAt ?? 0),
    );

    test('oldest fill first among matching mixes', () {
      final pick = suggestTripCylinder(
        states: [state('late', filledAt: 60), state('early', filledAt: 0)],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'early');
    });

    test('a matching mix beats an older fill of another mix', () {
      final pick = suggestTripCylinder(
        states: [
          state('air', o2: 21, filledAt: 0),
          state('ean', o2: 32, filledAt: 60),
        ],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'ean');
    });

    test('within one point of O2 counts as matching', () {
      final pick = suggestTripCylinder(
        states: [
          state('a', o2: 31.2, filledAt: 0),
          state('b', o2: 34, filledAt: 60),
        ],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'a');
    });

    test('an air tank takes the oldest full slot whatever its mix', () {
      final pick = suggestTripCylinder(
        states: [
          state('ean', o2: 32, filledAt: 0),
          state('air', o2: 21, filledAt: 60),
        ],
        tankMix: const GasMix(),
      );
      expect(pick!.id, 'ean');
    });

    test('no matching mix falls back to any full slot', () {
      final pick = suggestTripCylinder(
        states: [state('air', o2: 21, filledAt: 0)],
        tankMix: const GasMix(o2: 36),
      );
      expect(pick!.id, 'air');
    });

    test('only full slots qualify, and excluded ones are skipped', () {
      final pick = suggestTripCylinder(
        states: [
          state('used', status: TripCylinderStatus.partial, filledAt: 0),
          state('sibling', filledAt: 10),
          state('free', filledAt: 20),
        ],
        tankMix: const GasMix(o2: 32),
        excludedCylinderIds: {'sibling'},
      );
      expect(pick!.id, 'free');
    });

    test('nothing full means no suggestion', () {
      expect(
        suggestTripCylinder(
          states: [state('a', status: TripCylinderStatus.empty)],
          tankMix: const GasMix(o2: 32),
        ),
        isNull,
      );
      expect(
        suggestTripCylinder(states: const [], tankMix: const GasMix()),
        isNull,
      );
    });

    test('a slot full by gauge reading sorts after any filled slot', () {
      final pick = suggestTripCylinder(
        states: [
          state('gauge', filledAt: null),
          state('filled', filledAt: 300),
        ],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'filled');
    });

    test('ties break on board order', () {
      final pick = suggestTripCylinder(
        states: [
          state('second', filledAt: 0, sortOrder: 1),
          state('first', filledAt: 0, sortOrder: 0),
        ],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'first');
    });
  });
}
