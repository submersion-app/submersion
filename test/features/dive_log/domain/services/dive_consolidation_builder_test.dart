import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';

Dive makeDive(
  String id, {
  required DateTime entry,
  int runtimeMin = 30,
  String? diverId = 'diver1',
  String? serial,
  List<DiveTank> tanks = const [],
  List<DiveProfilePoint> profile = const [],
}) => Dive(
  id: id,
  diverId: diverId,
  dateTime: entry,
  entryTime: entry,
  runtime: Duration(minutes: runtimeMin),
  diveComputerSerial: serial,
  tanks: tanks,
  profile: profile,
);

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

    test('a null secondary startPressure conservatively blocks the merge', () {
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
      expect(plan.tankMerges.containsKey('s1'), isFalse);
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
}
