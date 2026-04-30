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
  });
}
