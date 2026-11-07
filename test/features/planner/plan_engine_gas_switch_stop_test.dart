import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Issue #4160: "Gas switch stop" is held at the depth where the gas is
/// switched, through the whole planner: stops, table, TTS and the no-deco
/// readouts.

const _air = GasMix();
const _ean50 = GasMix(o2: 50);
const _o2 = GasMix(o2: 100);

domain.DivePlan _plan({
  required double depth,
  required int minutes,
  int? gasSwitchStopSeconds,
}) => domain.DivePlan(
  id: 'switch-stop',
  name: 'Switch stop',
  mode: domain.PlanMode.oc,
  gfLow: 40,
  gfHigh: 80,
  gasSwitchStopSeconds: gasSwitchStopSeconds,
  createdAt: DateTime(2026, 11, 7),
  updatedAt: DateTime(2026, 11, 7),
  tanks: const [
    DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _air),
    DiveTank(
      id: 'ean50',
      volume: 7,
      startPressure: 200,
      gasMix: _ean50,
      role: TankRole.deco,
    ),
    DiveTank(
      id: 'o2',
      volume: 7,
      startPressure: 200,
      gasMix: _o2,
      role: TankRole.deco,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: depth,
      tankId: 'back',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'back',
      gasMix: _air,
      order: 1,
    ),
  ],
);

PlanStop? _stopAt(PlanOutcome outcome, double depth) =>
    outcome.stops.where((s) => s.depthMeters == depth).firstOrNull;

void main() {
  const engine = PlanEngine();

  group('the issue plan: 40 m for 12 min on air, EAN50 and O2', () {
    test('holds the EAN50 switch at 21 m on EAN50', () {
      final outcome = engine.compute(
        _plan(depth: 40, minutes: 12, gasSwitchStopSeconds: 60),
      );
      final switchStop = _stopAt(outcome, 21);
      expect(switchStop, isNotNull);
      expect(switchStop!.durationSeconds, 60);
      expect(switchStop.isGasSwitchOnly, isTrue);
      expect(switchStop.tankId, 'ean50');
      expect(outcome.owesDecompression, isTrue);
    });

    test('does not lengthen any stop where nothing is switched', () {
      final baseline = engine.compute(_plan(depth: 40, minutes: 25));
      final unswitched = baseline.stops.where(
        (s) => s.depthMeters != 21 && s.depthMeters != 6,
      );
      expect(unswitched, isNotEmpty, reason: 'precondition');
      final withSwitch = engine.compute(
        _plan(depth: 40, minutes: 25, gasSwitchStopSeconds: 5 * 60),
      );
      for (final before in unswitched) {
        final after = _stopAt(withSwitch, before.depthMeters);
        // Whole-minute snapping may move a stop by its leg's odd seconds, so
        // allow that much; a misplaced floor would add the full five minutes.
        expect(
          after?.durationSeconds ?? 0,
          lessThan(before.durationSeconds + 60),
          reason: 'nothing is switched at ${before.depthMeters} m',
        );
      }
    });

    test('the switch stop leaves the bottom-to-first-stop rate in force', () {
      final outcome = engine.compute(
        _plan(depth: 40, minutes: 12, gasSwitchStopSeconds: 60),
      );
      final switchStop = _stopAt(outcome, 21)!;
      final firstDeco = outcome.stops.firstWhere((s) => !s.isGasSwitchOnly);
      // 21 m to the first deco stop at the working 9 m/min.
      final legSeconds =
          firstDeco.arrivalRuntimeSeconds -
          (switchStop.arrivalRuntimeSeconds + switchStop.durationSeconds);
      expect(legSeconds, ((21 - firstDeco.depthMeters) / 9 * 60).round());
    });
  });

  group('a no-deco plan', () {
    test('holds a stop at each switch and still reads as no-deco', () {
      final outcome = engine.compute(
        _plan(depth: 30, minutes: 10, gasSwitchStopSeconds: 30),
      );
      expect(outcome.stops.map((s) => s.depthMeters), [21.0, 6.0]);
      expect(outcome.stops.map((s) => s.durationSeconds), [30, 30]);
      expect(outcome.stops.map((s) => s.tankId), ['ean50', 'o2']);
      expect(outcome.owesDecompression, isFalse);
      expect(outcome.totalDecoSeconds, 0);
      expect(outcome.ndlAtBottom, greaterThan(0));
    });

    test('times the ascent at the working rate, plus the switch stops', () {
      final without = engine.compute(_plan(depth: 30, minutes: 10));
      final withSwitch = engine.compute(
        _plan(depth: 30, minutes: 10, gasSwitchStopSeconds: 30),
      );
      expect(without.stops, isEmpty);
      expect(withSwitch.ttsAtBottom, without.ttsAtBottom + 60);
      expect(withSwitch.runtimeSeconds, without.runtimeSeconds + 60);
    });

    test('prints a table line for each switch stop', () {
      final outcome = engine.compute(
        _plan(depth: 30, minutes: 10, gasSwitchStopSeconds: 30),
      );
      final stopRows = outcome.schedule
          .where((row) => row.kind == PlanScheduleRowKind.stop)
          .toList();
      expect(stopRows.map((r) => r.depthMeters), [21.0, 6.0]);
      expect(stopRows.map((r) => r.tankId), ['ean50', 'o2']);
    });

    test('is unchanged with a switch stop of 0', () {
      expect(engine.compute(_plan(depth: 30, minutes: 10)).stops, isEmpty);
    });
  });
}
