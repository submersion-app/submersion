import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

DiveTank _tank({
  required String id,
  required double o2,
  double he = 0,
  String? name,
  int order = 0,
}) {
  return DiveTank(
    id: id,
    name: name,
    gasMix: GasMix(o2: o2, he: he),
    order: order,
  );
}

GasSwitchWithTank _switch({
  required String tankId,
  required int timestamp,
  required double o2Fraction,
  double heFraction = 0,
  String tankName = '',
  String gasMix = '',
}) {
  return GasSwitchWithTank(
    gasSwitch: GasSwitch(
      id: 'gs-$timestamp',
      diveId: 'dive-1',
      timestamp: timestamp,
      tankId: tankId,
      createdAt: DateTime(2026, 1, 1),
    ),
    tankName: tankName,
    gasMix: gasMix,
    o2Fraction: o2Fraction,
    heFraction: heFraction,
  );
}

void main() {
  group('buildGasUsageSegments', () {
    test('returns empty list when there are no tanks', () {
      final segments = buildGasUsageSegments(
        tanks: const [],
        gasSwitches: const [],
        diveDurationSeconds: 1800,
      );
      expect(segments, isEmpty);
    });

    test('returns empty list when dive duration is zero', () {
      final segments = buildGasUsageSegments(
        tanks: [_tank(id: 't1', o2: 21)],
        gasSwitches: const [],
        diveDurationSeconds: 0,
      );
      expect(segments, isEmpty);
    });

    test(
      'single tank with no switches yields one segment covering the dive',
      () {
        final tank = _tank(id: 't1', o2: 21, name: 'Primary');
        final segments = buildGasUsageSegments(
          tanks: [tank],
          gasSwitches: const [],
          diveDurationSeconds: 3000,
        );
        expect(segments, hasLength(1));
        expect(segments.single.startSeconds, 0);
        expect(segments.single.endSeconds, 3000);
        expect(segments.single.gasMix.o2, 21);
        expect(segments.single.tankName, 'Primary');
        expect(segments.single.label, 'Air');
      },
    );

    test('first switch at t=0 emits one segment per switch boundary', () {
      final back = _tank(id: 'back', o2: 21);
      final deco = _tank(id: 'deco', o2: 50, order: 1);
      final segments = buildGasUsageSegments(
        tanks: [back, deco],
        gasSwitches: [
          _switch(tankId: 'back', timestamp: 0, o2Fraction: 0.21),
          _switch(tankId: 'deco', timestamp: 1500, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 3000,
      );
      expect(segments, hasLength(2));
      expect(segments[0].startSeconds, 0);
      expect(segments[0].endSeconds, 1500);
      expect(segments[0].gasMix.o2, 21);
      expect(segments[1].startSeconds, 1500);
      expect(segments[1].endSeconds, 3000);
      expect(segments[1].gasMix.o2, 50);
    });

    test('first switch after t=0 inserts a starting-tank segment from t=0', () {
      final back = _tank(id: 'back', o2: 32, name: 'Back');
      final deco = _tank(id: 'deco', o2: 80, order: 1);
      final segments = buildGasUsageSegments(
        tanks: [back, deco],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 600, o2Fraction: 0.80),
        ],
        diveDurationSeconds: 1800,
      );
      expect(segments, hasLength(2));
      expect(segments[0].startSeconds, 0);
      expect(segments[0].endSeconds, 600);
      expect(segments[0].gasMix.o2, 32);
      expect(segments[0].tankName, 'Back');
      expect(segments[1].startSeconds, 600);
      expect(segments[1].endSeconds, 1800);
      expect(segments[1].gasMix.o2, 80);
    });

    test('starting tank is the lowest-order tank, not list position', () {
      final later = _tank(id: 'late', o2: 100, name: 'Late', order: 2);
      final first = _tank(id: 'first', o2: 21, name: 'First', order: 0);
      final segments = buildGasUsageSegments(
        tanks: [later, first],
        gasSwitches: const [],
        diveDurationSeconds: 1200,
      );
      expect(segments, hasLength(1));
      expect(segments.single.tankName, 'First');
      expect(segments.single.gasMix.o2, 21);
    });

    test('switch back to the same gas merges with the previous segment', () {
      final back = _tank(id: 'back', o2: 21);
      final deco = _tank(id: 'deco', o2: 21, order: 1);
      final segments = buildGasUsageSegments(
        tanks: [back, deco],
        gasSwitches: [
          _switch(tankId: 'back', timestamp: 0, o2Fraction: 0.21),
          _switch(tankId: 'deco', timestamp: 600, o2Fraction: 0.21),
          _switch(tankId: 'back', timestamp: 1200, o2Fraction: 0.21),
        ],
        diveDurationSeconds: 1800,
      );
      expect(segments, hasLength(1));
      expect(segments.single.startSeconds, 0);
      expect(segments.single.endSeconds, 1800);
    });

    test('switches outside dive bounds are dropped', () {
      final tank = _tank(id: 't1', o2: 21);
      final tank2 = _tank(id: 't2', o2: 50, order: 1);
      final segments = buildGasUsageSegments(
        tanks: [tank, tank2],
        gasSwitches: [
          _switch(tankId: 't2', timestamp: -10, o2Fraction: 0.50),
          _switch(tankId: 't2', timestamp: 5000, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 1800,
      );
      expect(segments, hasLength(1));
      expect(segments.single.gasMix.o2, 21);
    });

    test('unsorted switches are normalised before segment construction', () {
      final back = _tank(id: 'back', o2: 21);
      final deco = _tank(id: 'deco', o2: 50, order: 1);
      final segments = buildGasUsageSegments(
        tanks: [back, deco],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1500, o2Fraction: 0.50),
          _switch(tankId: 'back', timestamp: 0, o2Fraction: 0.21),
        ],
        diveDurationSeconds: 3000,
      );
      expect(segments, hasLength(2));
      expect(segments[0].endSeconds, 1500);
      expect(segments[1].startSeconds, 1500);
    });

    test('trimix segment exposes both o2 and he percentages', () {
      final back = _tank(id: 'back', o2: 21, he: 35, order: 0);
      final segments = buildGasUsageSegments(
        tanks: [back],
        gasSwitches: [
          _switch(
            tankId: 'back',
            timestamp: 0,
            o2Fraction: 0.18,
            heFraction: 0.45,
          ),
        ],
        diveDurationSeconds: 2400,
      );
      expect(segments, hasLength(1));
      expect(segments.single.gasMix.o2, 18);
      expect(segments.single.gasMix.he, 45);
      expect(segments.single.label, 'Tx 18/45');
    });

    test(
      'gas change at the first sample declares the initial gas, not a switch',
      () {
        // Subsurface writes the starting gas as a gaschange event at the first
        // sample (t=10), never at t=0, and it may name a cylinder other than
        // the lowest-order one (fixtures 002 and 003 do exactly this).
        final deco = _tank(id: 'deco', o2: 32, name: 'Deco');
        final back = _tank(id: 'back', o2: 21, name: 'Back', order: 1);
        final segments = buildGasUsageSegments(
          tanks: [deco, back],
          gasSwitches: [
            _switch(tankId: 'back', timestamp: 10, o2Fraction: 0.21),
          ],
          diveDurationSeconds: 1800,
          firstSampleSeconds: 10,
        );
        expect(segments, hasLength(1));
        expect(segments.single.startSeconds, 0);
        expect(segments.single.endSeconds, 1800);
        expect(segments.single.gasMix.o2, 21);
        expect(segments.single.tankName, 'Back');
      },
    );

    test('a genuine mid-dive switch still gets its own segment', () {
      final deco = _tank(id: 'deco', o2: 50, name: 'Deco');
      final back = _tank(id: 'back', o2: 21, name: 'Back', order: 1);
      final segments = buildGasUsageSegments(
        tanks: [deco, back],
        gasSwitches: [
          _switch(tankId: 'back', timestamp: 10, o2Fraction: 0.21),
          _switch(tankId: 'deco', timestamp: 1500, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 3000,
        firstSampleSeconds: 10,
      );
      expect(segments, hasLength(2));
      expect(segments[0].startSeconds, 0);
      expect(segments[0].endSeconds, 1500);
      expect(segments[0].gasMix.o2, 21);
      expect(segments[1].startSeconds, 1500);
      expect(segments[1].endSeconds, 3000);
      expect(segments[1].gasMix.o2, 50);
    });

    test(
      'a switch after the first sample still gets a starting-tank segment',
      () {
        final back = _tank(id: 'back', o2: 32, name: 'Back');
        final deco = _tank(id: 'deco', o2: 80, order: 1);
        final segments = buildGasUsageSegments(
          tanks: [back, deco],
          gasSwitches: [
            _switch(tankId: 'deco', timestamp: 600, o2Fraction: 0.80),
          ],
          diveDurationSeconds: 1800,
          firstSampleSeconds: 10,
        );
        expect(segments, hasLength(2));
        expect(segments[0].startSeconds, 0);
        expect(segments[0].endSeconds, 600);
        expect(segments[0].gasMix.o2, 32);
      },
    );

    // Sample intervals vary by computer: 1s and 2s on Shearwater, 4s/5s on
    // Suunto, 10s in Subsurface's default export, 20s/30s on older units. The
    // rule keys off the dive's own first sample, never a fixed constant.
    for (final firstSample in const [0, 1, 2, 4, 5, 10, 20, 30, 60]) {
      test('initial-gas declaration is recognised at a first sample of '
          '${firstSample}s', () {
        final deco = _tank(id: 'deco', o2: 32, name: 'Deco');
        final back = _tank(id: 'back', o2: 21, name: 'Back', order: 1);
        final segments = buildGasUsageSegments(
          tanks: [deco, back],
          gasSwitches: [
            _switch(tankId: 'back', timestamp: firstSample, o2Fraction: 0.21),
          ],
          diveDurationSeconds: 1800,
          firstSampleSeconds: firstSample,
        );
        expect(segments, hasLength(1));
        expect(segments.single.startSeconds, 0);
        expect(segments.single.endSeconds, 1800);
        expect(segments.single.gasMix.o2, 21);
        expect(segments.single.tankName, 'Back');
      });
    }

    test('a switch one second after the first sample is a real switch', () {
      final back = _tank(id: 'back', o2: 21, name: 'Back');
      final deco = _tank(id: 'deco', o2: 50, name: 'Deco', order: 1);
      final segments = buildGasUsageSegments(
        tanks: [back, deco],
        gasSwitches: [_switch(tankId: 'deco', timestamp: 5, o2Fraction: 0.50)],
        diveDurationSeconds: 1800,
        firstSampleSeconds: 4,
      );
      expect(segments, hasLength(2));
      expect(segments[0].startSeconds, 0);
      expect(segments[0].endSeconds, 5);
      expect(segments[0].gasMix.o2, 21);
      expect(segments[1].startSeconds, 5);
      expect(segments[1].gasMix.o2, 50);
    });
  });

  group('buildActiveTankIntervals', () {
    test('empty when no tanks or zero duration', () {
      expect(
        buildActiveTankIntervals(
          tanks: const [],
          gasSwitches: const [],
          diveDurationSeconds: 1800,
        ),
        isEmpty,
      );
      expect(
        buildActiveTankIntervals(
          tanks: [_tank(id: 't1', o2: 21)],
          gasSwitches: const [],
          diveDurationSeconds: 0,
        ),
        isEmpty,
      );
    });

    test(
      'single tank, no switches -> one full-dive interval for lowest order',
      () {
        final result = buildActiveTankIntervals(
          tanks: [
            _tank(id: 'late', o2: 100, order: 2),
            _tank(id: 'first', o2: 21),
          ],
          gasSwitches: const [],
          diveDurationSeconds: 2400,
        );
        expect(result.keys, ['first']);
        expect(result['first'], [(start: 0, end: 2400)]);
      },
    );

    test('deco bottle owns only its switch window', () {
      final result = buildActiveTankIntervals(
        tanks: [
          _tank(id: 'back', o2: 21),
          _tank(id: 'deco', o2: 50, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1200, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 1800,
      );
      expect(result['back'], [(start: 0, end: 1200)]);
      expect(result['deco'], [(start: 1200, end: 1800)]);
    });

    test('back gas returned to yields two intervals with a gap', () {
      final result = buildActiveTankIntervals(
        tanks: [
          _tank(id: 'back', o2: 21),
          _tank(id: 'deco', o2: 50, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: 1200, o2Fraction: 0.50),
          _switch(tankId: 'back', timestamp: 1800, o2Fraction: 0.21),
        ],
        diveDurationSeconds: 2400,
      );
      expect(result['back'], [(start: 0, end: 1200), (start: 1800, end: 2400)]);
      expect(result['deco'], [(start: 1200, end: 1800)]);
    });

    test('switch exactly at t=0 produces no zero-length leading interval', () {
      final result = buildActiveTankIntervals(
        tanks: [
          _tank(id: 'back', o2: 21),
          _tank(id: 'deco', o2: 50, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'back', timestamp: 0, o2Fraction: 0.21),
          _switch(tankId: 'deco', timestamp: 1500, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 3000,
      );
      expect(result['back'], [(start: 0, end: 1500)]);
      expect(result['deco'], [(start: 1500, end: 3000)]);
    });

    test('out-of-bounds switches are dropped', () {
      final result = buildActiveTankIntervals(
        tanks: [
          _tank(id: 'back', o2: 21),
          _tank(id: 'deco', o2: 50, order: 1),
        ],
        gasSwitches: [
          _switch(tankId: 'deco', timestamp: -10, o2Fraction: 0.50),
          _switch(tankId: 'deco', timestamp: 9000, o2Fraction: 0.50),
        ],
        diveDurationSeconds: 1800,
      );
      expect(result['back'], [(start: 0, end: 1800)]);
      expect(result.containsKey('deco'), isFalse);
    });

    test('gas change at the first sample owns the window from t=0, not the '
        'lowest-order tank', () {
      final result = buildActiveTankIntervals(
        tanks: [
          _tank(id: 'deco', o2: 32),
          _tank(id: 'back', o2: 21, order: 1),
        ],
        gasSwitches: [_switch(tankId: 'back', timestamp: 10, o2Fraction: 0.21)],
        diveDurationSeconds: 1800,
        firstSampleSeconds: 10,
      );
      expect(result['back'], [(start: 0, end: 1800)]);
      expect(result.containsKey('deco'), isFalse);
    });
  });
}
