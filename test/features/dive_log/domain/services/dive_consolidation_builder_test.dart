import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

Dive makeDive(
  String id, {
  required DateTime entry,
  int runtimeMin = 30,
  String? diverId = 'diver1',
  String? serial,
  String? computerId,
  List<DiveTank> tanks = const [],
  List<DiveProfilePoint> profile = const [],
}) => Dive(
  id: id,
  diverId: diverId,
  dateTime: entry,
  entryTime: entry,
  runtime: Duration(minutes: runtimeMin),
  diveComputerSerial: serial,
  computerId: computerId,
  tanks: tanks,
  profile: profile,
);

/// A multilevel reef dive sampled every 10 s; [lead] seconds at the surface
/// first.
List<DiveProfilePoint> reefProfile({int lead = 0}) {
  const knots = <(int, double)>[
    (0, 0),
    (120, 18),
    (240, 22),
    (600, 21),
    (900, 16),
    (1300, 14),
    (1700, 10),
    (2200, 8),
    (2400, 5),
    (2580, 5),
    (2760, 4.8),
    (2880, 0),
  ];
  double at(int t) {
    for (var i = 1; i < knots.length; i++) {
      final (t0, d0) = knots[i - 1];
      final (t1, d1) = knots[i];
      if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
    }
    return 0;
  }

  return [
    for (var t = 0; t <= 2880 + lead; t += 10)
      DiveProfilePoint(timestamp: t, depth: t < lead ? 0 : at(t - lead)),
  ];
}

void main() {
  const builder = DiveConsolidationBuilder();
  final t = DateTime.utc(2026, 7, 1, 9);

  group('classify', () {
    test('fewer than 2 dives is invalid', () {
      final result = builder.classify([makeDive('a', entry: t)]);
      expect(result, isA<ConsolidationInvalid>());
      expect(
        (result as ConsolidationInvalid).reason,
        ConsolidationInvalidReason.tooFewDives,
      );
    });

    test('mixed divers is invalid', () {
      final result = builder.classify([
        makeDive('a', entry: t),
        makeDive(
          'b',
          entry: t.add(const Duration(minutes: 10)),
          diverId: 'diver2',
        ),
      ]);
      expect(result, isA<ConsolidationInvalid>());
      expect(
        (result as ConsolidationInvalid).reason,
        ConsolidationInvalidReason.mixedDivers,
      );
    });

    test('identical non-null computer serial is invalid', () {
      final result = builder.classify([
        makeDive('a', entry: t, serial: 'XYZ123'),
        makeDive(
          'b',
          entry: t.add(const Duration(minutes: 10)),
          serial: 'XYZ123',
        ),
      ]);
      expect(result, isA<ConsolidationInvalid>());
      expect(
        (result as ConsolidationInvalid).reason,
        ConsolidationInvalidReason.sameComputer,
      );
    });

    test('dive entirely after the other is not overlapping', () {
      final result = builder.classify([
        makeDive('a', entry: t, runtimeMin: 30),
        makeDive('b', entry: t.add(const Duration(hours: 2))),
      ]);
      expect(result, isA<ConsolidationInvalid>());
      expect(
        (result as ConsolidationInvalid).reason,
        ConsolidationInvalidReason.notOverlapping,
      );
    });

    test(
      'overlapping dives with no primaryDiveId use the earlier entry as primary',
      () {
        final a = makeDive('a', entry: t, runtimeMin: 40);
        final b = makeDive(
          'b',
          entry: t.add(const Duration(minutes: 10)),
          runtimeMin: 40,
        );
        final result = builder.classify([b, a]);
        expect(result, isA<ConsolidationReady>());
        final ready = result as ConsolidationReady;
        expect(ready.primary.id, 'a');
        expect(ready.secondaries.map((d) => d.id), ['b']);
      },
    );

    // A dive logged with no runtime and no profile has no length, so it is an
    // instant. A re-import of it starting at that instant must still fold
    // into it, or the re-import cannot repair it (#1809).
    group('a dive of unknown length', () {
      final instant = Dive(
        id: 'a',
        diverId: 'diver1',
        dateTime: t,
        entryTime: t,
      );

      test('overlaps a dive starting at the same instant', () {
        final result = builder.classify([
          instant,
          makeDive('b', entry: t, runtimeMin: 45),
        ], primaryDiveId: 'a');
        expect(result, isA<ConsolidationReady>());
      });

      test('overlaps another of unknown length at the same instant', () {
        final other = Dive(
          id: 'b',
          diverId: 'diver1',
          dateTime: t,
          entryTime: t,
        );
        expect(builder.classify([instant, other]), isA<ConsolidationReady>());
      });

      test('overlaps a dive that is under way at that instant', () {
        final result = builder.classify([
          instant,
          makeDive(
            'b',
            entry: t.subtract(const Duration(minutes: 5)),
            runtimeMin: 45,
          ),
        ]);
        expect(result, isA<ConsolidationReady>());
      });

      // DiveMatcher scores starts up to 5 minutes apart as the same dive, so
      // a matched re-import can start a little after the instant.
      test('overlaps a dive starting a few minutes after it', () {
        final result = builder.classify([
          instant,
          makeDive(
            'b',
            entry: t.add(const Duration(minutes: 3)),
            runtimeMin: 45,
          ),
        ], primaryDiveId: 'a');
        expect(result, isA<ConsolidationReady>());
      });

      // A recorded zero runtime is a length, not a missing one: it is not
      // stretched to the other dive's.
      test('a recorded zero runtime does not borrow the other length', () {
        final result = builder.classify([
          makeDive('a', entry: t, runtimeMin: 0),
          makeDive(
            'b',
            entry: t.add(const Duration(minutes: 3)),
            runtimeMin: 45,
          ),
        ]);
        expect(
          (result as ConsolidationInvalid).reason,
          ConsolidationInvalidReason.notOverlapping,
        );
      });

      test('does not overlap a dive starting after that length', () {
        final result = builder.classify([
          instant,
          makeDive(
            'b',
            entry: t.add(const Duration(minutes: 50)),
            runtimeMin: 45,
          ),
        ]);
        expect(
          (result as ConsolidationInvalid).reason,
          ConsolidationInvalidReason.notOverlapping,
        );
      });

      test('does not overlap a dive that ended before it', () {
        final result = builder.classify([
          instant,
          makeDive(
            'b',
            entry: t.subtract(const Duration(hours: 1)),
            runtimeMin: 45,
          ),
        ]);
        expect(
          (result as ConsolidationInvalid).reason,
          ConsolidationInvalidReason.notOverlapping,
        );
      });
    });

    test('overlapping dives honor an explicit primaryDiveId', () {
      final a = makeDive('a', entry: t, runtimeMin: 40);
      final b = makeDive(
        'b',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 40,
      );
      final result = builder.classify([a, b], primaryDiveId: 'b');
      expect(result, isA<ConsolidationReady>());
      final ready = result as ConsolidationReady;
      expect(ready.primary.id, 'b');
      expect(ready.secondaries.map((d) => d.id), ['a']);
    });
  });

  group('build - offsets', () {
    test('secondary entered after the primary gets a positive offset', () {
      final primary = makeDive('p', entry: t, runtimeMin: 60);
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(seconds: 90)),
        runtimeMin: 30,
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.offsetsSeconds, {'p': 0, 's': 90});
    });

    test('secondary entered before the primary gets a negative offset', () {
      final primary = makeDive('y', entry: t, runtimeMin: 30);
      final secondary = makeDive(
        'x',
        entry: t.subtract(const Duration(seconds: 30)),
        runtimeMin: 5,
      );
      final plan = builder.build([secondary, primary], primaryDiveId: 'y');
      expect(plan.primary.id, 'y');
      expect(plan.offsetsSeconds, {'y': 0, 'x': -30});
    });
  });

  group('build - tank dedup', () {
    test(
      'close gas and pressures merge the secondary tank into the primary',
      () {
        const primaryTank = DiveTank(
          id: 'p1',
          gasMix: GasMix(o2: 31.8, he: 0.0),
          startPressure: 207,
          endPressure: 63,
        );
        const secondaryTank = DiveTank(
          id: 's1',
          gasMix: GasMix(o2: 32.0, he: 0.0),
          startPressure: 210,
          endPressure: 60,
        );
        final primary = makeDive(
          'p',
          entry: t,
          runtimeMin: 40,
          tanks: [primaryTank],
        );
        final secondary = makeDive(
          's',
          entry: t.add(const Duration(minutes: 10)),
          runtimeMin: 30,
          tanks: [secondaryTank],
        );
        final plan = builder.build([primary, secondary]);
        expect(plan.tankMerges, {'s1': 'p1'});
      },
    );

    test(
      'matching transmitter serials merge even when the programmed mix differs',
      () {
        // Two Terics paired to the same transmitter: one programmed 31%,
        // the other 32%. Same physical cylinder, so the gas gate must yield.
        const primaryTank = DiveTank(
          id: 'p1',
          gasMix: GasMix(o2: 31.0, he: 0.0),
          startPressure: 207,
          endPressure: 63,
          transmitterSerial: '180777',
        );
        const secondaryTank = DiveTank(
          id: 's1',
          gasMix: GasMix(o2: 32.0, he: 0.0),
          startPressure: 208,
          endPressure: 64,
          transmitterSerial: '180777',
        );
        final primary = makeDive(
          'p',
          entry: t,
          runtimeMin: 40,
          tanks: [primaryTank],
        );
        final secondary = makeDive(
          's',
          entry: t.add(const Duration(minutes: 10)),
          runtimeMin: 30,
          tanks: [secondaryTank],
        );
        final plan = builder.build([primary, secondary]);
        expect(plan.tankMerges, {'s1': 'p1'});
      },
    );

    test('matching transmitter serials merge even when pressures disagree', () {
      // The transmitter is the cylinder's identity; a pressure gap only
      // says the two computers logged it at different moments.
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        startPressure: 207,
        endPressure: 63,
        transmitterSerial: '180777',
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        startPressure: 190,
        endPressure: 80,
        transmitterSerial: '180777',
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges, {'s1': 'p1'});
    });

    test(
      'differing transmitter serials never merge, even on identical data',
      () {
        // Twin cylinders on the same mix with their own transmitters are two
        // tanks, however closely their readings agree.
        const primaryTank = DiveTank(
          id: 'p1',
          gasMix: GasMix(o2: 32.0, he: 0.0),
          startPressure: 207,
          endPressure: 63,
          transmitterSerial: '180777',
        );
        const secondaryTank = DiveTank(
          id: 's1',
          gasMix: GasMix(o2: 32.0, he: 0.0),
          startPressure: 207,
          endPressure: 63,
          transmitterSerial: '180778',
        );
        final primary = makeDive(
          'p',
          entry: t,
          runtimeMin: 40,
          tanks: [primaryTank],
        );
        final secondary = makeDive(
          's',
          entry: t.add(const Duration(minutes: 10)),
          runtimeMin: 30,
          tanks: [secondaryTank],
        );
        final plan = builder.build([primary, secondary]);
        expect(plan.tankMerges, isEmpty);
      },
    );

    test('a zero sentinel serial on both sides is no identity at all', () {
      // "0" is libdivecomputer's "no transmitter"; two such tanks must fall
      // back to the gas-mix rule, which here keeps them apart.
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 31.0, he: 0.0),
        transmitterSerial: '0',
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        transmitterSerial: '0',
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      expect(builder.build([primary, secondary]).tankMerges, isEmpty);
    });

    test('every secondary on the same transmitter merges into one primary '
        'tank', () {
      // Three computers paired to one transmitter: the primary tank must
      // absorb BOTH secondaries' tanks, not just the first one's.
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        transmitterSerial: '180777',
      );
      const secondaryTank1 = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 31.0, he: 0.0),
        transmitterSerial: '180777',
      );
      const secondaryTank2 = DiveTank(
        id: 's2',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        transmitterSerial: '180777',
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary1 = makeDive(
        's-one',
        entry: t.add(const Duration(minutes: 5)),
        runtimeMin: 30,
        tanks: [secondaryTank1],
      );
      final secondary2 = makeDive(
        's-two',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank2],
      );
      final plan = builder.build([primary, secondary1, secondary2]);
      expect(plan.tankMerges, {'s1': 'p1', 's2': 'p1'});
    });

    test(
      'two tanks of one secondary never both claim the same primary tank',
      () {
        // Within a single secondary the claim is exclusive: its second tank on
        // the same mix is a second cylinder, not a second reading of the first.
        const primaryTank = DiveTank(
          id: 'p1',
          gasMix: GasMix(o2: 32.0, he: 0.0),
        );
        const secondaryTank1 = DiveTank(
          id: 's1',
          gasMix: GasMix(o2: 32.0, he: 0.0),
        );
        const secondaryTank2 = DiveTank(
          id: 's2',
          gasMix: GasMix(o2: 32.0, he: 0.0),
          order: 1,
        );
        final primary = makeDive(
          'p',
          entry: t,
          runtimeMin: 40,
          tanks: [primaryTank],
        );
        final secondary = makeDive(
          's',
          entry: t.add(const Duration(minutes: 10)),
          runtimeMin: 30,
          tanks: [secondaryTank1, secondaryTank2],
        );
        final plan = builder.build([primary, secondary]);
        expect(plan.tankMerges, {'s1': 'p1'});
      },
    );

    test('a serial on only one side falls back to the gas-mix rule', () {
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        startPressure: 207,
        endPressure: 63,
        transmitterSerial: '180777',
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        startPressure: 208,
        endPressure: 64,
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges, {'s1': 'p1'});
    });

    test('a serial match claims the primary tank that shares the serial, '
        'not the first tank with a close mix', () {
      // Primary: back gas (32%, serial A) then a stage (32%, no serial).
      // Secondary: one tank with serial A. It must land on the primary tank
      // carrying that serial rather than whichever tank is listed first.
      const primaryStage = DiveTank(
        id: 'p-stage',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        order: 0,
      );
      const primaryBack = DiveTank(
        id: 'p-back',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        order: 1,
        transmitterSerial: '180777',
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 32.0, he: 0.0),
        transmitterSerial: '180777',
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryStage, primaryBack],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges, {'s1': 'p-back'});
    });

    test('gas differing by more than 0.5% keeps tanks separate', () {
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 31.8),
        startPressure: 207,
        endPressure: 63,
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 33.0), // 1.2% away
        startPressure: 210,
        endPressure: 60,
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges.containsKey('s1'), isFalse);
    });

    test('pressures differing by more than 5 bar keep tanks separate', () {
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0),
        startPressure: 207,
        endPressure: 63,
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 31.8),
        startPressure: 215, // 8 bar away
        endPressure: 63,
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges.containsKey('s1'), isFalse);
    });

    test('a null secondary startPressure still merges on gas mix alone', () {
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0),
        startPressure: 207,
        endPressure: 63,
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 31.9),
        startPressure: null,
        endPressure: 60,
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges, {'s1': 'p1'});
    });

    test('a pressure that IS on both sides must still agree', () {
      // Only the secondary's start pressure is missing. Both sides report an
      // end pressure and they are 87 bar apart, so these are plainly not the
      // same cylinder and must not be merged. Skipping the whole pressure
      // check whenever any one of the four values is null would merge them.
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0),
        startPressure: 207,
        endPressure: 63,
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 32.0),
        startPressure: null,
        endPressure: 150,
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges.containsKey('s1'), isFalse);
    });

    test('a disagreeing start pressure blocks the merge on its own', () {
      // The mirror case: the end pressures are missing, the start pressures
      // are present and 100 bar apart.
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0),
        startPressure: 207,
        endPressure: null,
      );
      const secondaryTank = DiveTank(
        id: 's1',
        gasMix: GasMix(o2: 32.0),
        startPressure: 107,
        endPressure: null,
      );
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges.containsKey('s1'), isFalse);
    });

    test('no pressure at all on one side still merges on gas mix alone', () {
      // The case the relaxed rule exists for: a computer without air
      // integration reports no pressure, so gas mix is all there is to go on.
      const primaryTank = DiveTank(
        id: 'p1',
        gasMix: GasMix(o2: 32.0),
        startPressure: 207,
        endPressure: 63,
      );
      const secondaryTank = DiveTank(id: 's1', gasMix: GasMix(o2: 32.0));
      final primary = makeDive(
        'p',
        entry: t,
        runtimeMin: 40,
        tanks: [primaryTank],
      );
      final secondary = makeDive(
        's',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 30,
        tanks: [secondaryTank],
      );
      final plan = builder.build([primary, secondary]);
      expect(plan.tankMerges, {'s1': 'p1'});
    });

    test(
      'two secondary tanks cannot both merge into the same primary tank',
      () {
        const primaryTank = DiveTank(
          id: 'p1',
          gasMix: GasMix(o2: 32.0),
          startPressure: 207,
          endPressure: 63,
        );
        const secondaryTank1 = DiveTank(
          id: 's1',
          gasMix: GasMix(o2: 31.9),
          startPressure: 210,
          endPressure: 60,
        );
        const secondaryTank2 = DiveTank(
          id: 's2',
          gasMix: GasMix(o2: 32.1),
          startPressure: 208,
          endPressure: 62,
        );
        final primary = makeDive(
          'p',
          entry: t,
          runtimeMin: 40,
          tanks: [primaryTank],
        );
        final secondary = makeDive(
          's',
          entry: t.add(const Duration(minutes: 10)),
          runtimeMin: 30,
          tanks: [secondaryTank1, secondaryTank2],
        );
        final plan = builder.build([primary, secondary]);
        expect(plan.tankMerges, {'s1': 'p1'});
        expect(plan.tankMerges.containsKey('s2'), isFalse);
      },
    );
  });

  group('build - preview series', () {
    test('secondary series is shifted by its offset; negatives preserved', () {
      final primary = makeDive('y', entry: t, runtimeMin: 30);
      final secondary = makeDive(
        'x',
        entry: t.subtract(const Duration(seconds: 30)),
        runtimeMin: 5,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 5),
          DiveProfilePoint(timestamp: 20, depth: 10),
        ],
      );
      final plan = builder.build([secondary, primary], primaryDiveId: 'y');
      expect(plan.previewSeries['x'], [
        const DiveProfilePoint(timestamp: -30, depth: 5),
        const DiveProfilePoint(timestamp: -10, depth: 10),
      ]);
    });
  });

  group('build - multiple secondaries', () {
    test('primary plus two secondaries are classified and planned', () {
      final primary = makeDive('p', entry: t, runtimeMin: 60);
      final s1 = makeDive(
        's1',
        entry: t.add(const Duration(minutes: 5)),
        runtimeMin: 30,
      );
      final s2 = makeDive(
        's2',
        entry: t.add(const Duration(minutes: 10)),
        runtimeMin: 20,
      );
      final classification = builder.classify([s2, primary, s1]);
      expect(classification, isA<ConsolidationReady>());
      final ready = classification as ConsolidationReady;
      expect(ready.primary.id, 'p');
      expect(ready.secondaries.map((d) => d.id), ['s1', 's2']);

      final plan = builder.build([s2, primary, s1]);
      expect(plan.offsetsSeconds, {'p': 0, 's1': 300, 's2': 600});
      expect(plan.previewSeries.keys.toSet(), {'p', 's1', 's2'});
    });
  });

  group('build - invalid selection', () {
    test('throws ArgumentError for an invalid selection', () {
      expect(
        () => builder.build([makeDive('a', entry: t)]),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError whose message names the notOverlapping reason '
        '(so dive_detail_page.dart can map it to the right error text)', () {
      expect(
        () => builder.build([
          makeDive('a', entry: t, runtimeMin: 30),
          makeDive('b', entry: t.add(const Duration(hours: 2))),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('notOverlapping'),
          ),
        ),
      );
    });
  });

  group('alignment mode (#552)', () {
    // 'b' is the same dive on a computer whose clock runs 66 minutes fast
    // and which logged 40 s at the surface before the descent.
    List<Dive> skewedPair() => [
      makeDive(
        'a',
        entry: t,
        runtimeMin: 48,
        serial: 'A',
        profile: reefProfile(),
      ),
      makeDive(
        'b',
        entry: t.add(const Duration(minutes: 66)),
        runtimeMin: 48,
        serial: 'B',
        profile: reefProfile(lead: 40),
      ),
    ];

    test('a mode accepts a non-overlapping pair and marks it realigned', () {
      final result = builder.classify(
        skewedPair(),
        alignment: ConsolidationAlignment.bestFit,
      );
      expect(result, isA<ConsolidationReady>());
      expect((result as ConsolidationReady).realignedIds, {'b'});
    });

    test('a mode still rejects two records from one computer', () {
      final result = builder.classify([
        makeDive('a', entry: t, serial: 'SAME'),
        makeDive('b', entry: t.add(const Duration(hours: 2)), serial: 'SAME'),
      ], alignment: ConsolidationAlignment.bestFit);
      expect(
        (result as ConsolidationInvalid).reason,
        ConsolidationInvalidReason.sameComputer,
      );
    });

    test('two records sharing a computer id are one computer even with no '
        'serial', () {
      final result = builder.classify([
        makeDive('a', entry: t, computerId: 'comp-1'),
        makeDive(
          'b',
          entry: t.add(const Duration(hours: 2)),
          computerId: 'comp-1',
        ),
      ], alignment: ConsolidationAlignment.bestFit);
      expect(
        (result as ConsolidationInvalid).reason,
        ConsolidationInvalidReason.sameComputer,
      );
    });

    test('overlapping secondaries are not realigned', () {
      final result = builder.classify([
        makeDive('a', entry: t, serial: 'A'),
        makeDive('b', entry: t.add(const Duration(minutes: 5)), serial: 'B'),
        makeDive('c', entry: t.add(const Duration(minutes: 90)), serial: 'C'),
      ], alignment: ConsolidationAlignment.starts);
      expect((result as ConsolidationReady).realignedIds, {'c'});
    });

    test('realignedIds follows the chosen primary', () {
      final dives = [
        makeDive('a', entry: t, serial: 'A'),
        makeDive('b', entry: t.add(const Duration(minutes: 20)), serial: 'B'),
        makeDive('c', entry: t.add(const Duration(minutes: 45)), serial: 'C'),
      ];
      final fromA = builder.classify(
        dives,
        alignment: ConsolidationAlignment.bestFit,
      );
      final fromB = builder.classify(
        dives,
        primaryDiveId: 'b',
        alignment: ConsolidationAlignment.bestFit,
      );
      expect((fromA as ConsolidationReady).realignedIds, {'c'});
      expect((fromB as ConsolidationReady).realignedIds, isEmpty);
    });

    test(
      'best fit offsets a skewed secondary by its profile, not its clock',
      () {
        final plan = builder.build(
          skewedPair(),
          alignment: ConsolidationAlignment.bestFit,
        );
        expect(plan.offsetsSeconds['b'], -40);
        expect(plan.alignments['b']!.isStrongMatch, isTrue);
        expect(plan.previewSeries['b']!.first.timestamp, -40);
      },
    );

    test('align starts offsets the realigned secondary by 0 and keeps the '
        'best-fit score', () {
      final plan = builder.build(
        skewedPair(),
        alignment: ConsolidationAlignment.starts,
      );
      expect(plan.offsetsSeconds['b'], 0);
      expect(plan.alignments['b']!.offsetSeconds, 0);
      expect(plan.alignments['b']!.isStrongMatch, isTrue);
    });

    test('a mixed selection keeps the entry-time offset for an overlapping '
        'secondary', () {
      final plan = builder.build([
        makeDive(
          'a',
          entry: t,
          runtimeMin: 48,
          serial: 'A',
          profile: reefProfile(),
        ),
        makeDive(
          'b',
          entry: t.add(const Duration(minutes: 5)),
          runtimeMin: 48,
          serial: 'B',
          profile: reefProfile(),
        ),
        makeDive(
          'c',
          entry: t.add(const Duration(minutes: 90)),
          runtimeMin: 48,
          serial: 'C',
          profile: reefProfile(lead: 40),
        ),
      ], alignment: ConsolidationAlignment.bestFit);
      expect(plan.offsetsSeconds['b'], 300);
      expect(plan.offsetsSeconds['c'], -40);
      expect(plan.alignments.keys, ['c']);
    });

    test('without a mode the plan carries no alignments', () {
      final plan = builder.build([
        makeDive('a', entry: t, serial: 'A'),
        makeDive('b', entry: t.add(const Duration(minutes: 5)), serial: 'B'),
      ]);
      expect(plan.alignments, isEmpty);
    });
  });
}
