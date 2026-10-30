import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/air_break_runs.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _airBreaks = AirBreakPolicy(o2Seconds: 720, breakSeconds: 360);

/// The engine's model for these plans: their GFs, in their water.
final _model = BuhlmannGf(
  gfLow: 0.4,
  gfHigh: 0.8,
  environment: PlanEngine.environmentFor(_plan(depth: 18, bottomMinutes: 20)),
);

domain.DivePlan _plan({
  required double depth,
  required int bottomMinutes,
  bool withO2 = false,
  bool surfaceAtEnd = false,
  AirBreakPolicy? airBreaks,
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Surfaced tissue test',
    gfLow: 40,
    gfHigh: 80,
    airBreaks: airBreaks,
    tanks: [
      const DiveTank(
        id: 'back',
        volume: 11.1,
        startPressure: 207.0,
        gasMix: _air,
      ),
      if (withO2)
        const DiveTank(
          id: 'o2',
          volume: 11.1,
          startPressure: 207.0,
          gasMix: GasMix(o2: 100),
          role: TankRole.deco,
        ),
    ],
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: depth,
        tankId: 'back',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: depth,
        durationMinutes: bottomMinutes,
        tankId: 'back',
        gasMix: _air,
        order: 1,
      ),
      if (surfaceAtEnd)
        PlanSegment.travel(
          id: 'seg-3',
          fromDepth: depth,
          targetDepth: 0,
          tankId: 'back',
          gasMix: _air,
          order: 2,
          ratePerMinute: 9.0,
        ),
    ],
    createdAt: DateTime(2026, 10, 30),
    updatedAt: DateTime(2026, 10, 30),
  );
}

OpenCircuit _breathing(double fO2, double fHe) =>
    OpenCircuit(fO2: fO2, fHe: fHe);

/// The tissues after the computed ascent, worked out independently from the
/// printed schedule: each line after the authored ones on the gas it prints,
/// a stop's air breaks on air, and the travel between two stops, which the
/// table leaves as a gap in the runtime, on the gas of the line before it.
BuhlmannState _replaySchedule(
  PlanOutcome outcome,
  double lastDepth, {
  AirBreakPolicy? airBreaks,
}) {
  final authoredEnd = outcome.runtimeSeconds - outcome.ttsAtBottom;
  TissueState state = outcome.endTissue;
  var depth = lastDepth;
  var clock = authoredEnd;
  OpenCircuit? previousGas;
  for (final row in outcome.schedule) {
    final gas = _breathing(row.gasFO2, row.gasFHe);
    if (row.startRuntimeSeconds < authoredEnd) {
      previousGas = gas;
      continue;
    }
    final gap = row.startRuntimeSeconds - clock;
    if (gap > 0) {
      state = _model.applySegment(
        state,
        DecoSegment(
          startDepth: depth,
          endDepth: row.depthMeters,
          durationSeconds: gap,
        ),
        previousGas!,
      );
      depth = row.depthMeters;
    }
    if (row.kind == PlanScheduleRowKind.stop &&
        row.airBreakSeconds > 0 &&
        airBreaks != null) {
      for (final run in airBreakRuns(row.durationSeconds, airBreaks)) {
        state = _model.applySegment(
          state,
          DecoSegment(
            startDepth: depth,
            endDepth: depth,
            durationSeconds: run.seconds,
          ),
          run.onBreak ? _breathing(0.21, 0) : gas,
        );
      }
    } else {
      state = _model.applySegment(
        state,
        DecoSegment(
          startDepth: depth,
          endDepth: row.depthMeters,
          durationSeconds: row.durationSeconds,
        ),
        gas,
      );
    }
    depth = row.depthMeters;
    clock = row.runtimeSeconds;
    previousGas = gas;
  }
  return state as BuhlmannState;
}

void _expectSameTissues(BuhlmannState actual, BuhlmannState expected) {
  expect(actual.compartments, hasLength(expected.compartments.length));
  for (var i = 0; i < expected.compartments.length; i++) {
    expect(
      actual.compartments[i].currentPN2,
      closeTo(expected.compartments[i].currentPN2, 1e-6),
      reason: 'N2 in compartment ${i + 1}',
    );
    expect(
      actual.compartments[i].currentPHe,
      closeTo(expected.compartments[i].currentPHe, 1e-6),
      reason: 'He in compartment ${i + 1}',
    );
  }
}

void main() {
  const engine = PlanEngine();

  group('PlanOutcome.surfacedTissue', () {
    test('is the end tissue when the plan already ends at the surface', () {
      final outcome = engine.compute(
        _plan(depth: 18, bottomMinutes: 20, surfaceAtEnd: true),
      );

      expect(outcome.stops, isEmpty);
      _expectSameTissues(outcome.surfacedTissue, outcome.endTissue);
    });

    test('includes the computed ascent of a no-deco dive', () {
      final outcome = engine.compute(_plan(depth: 18, bottomMinutes: 20));

      expect(outcome.stops, isEmpty);
      final expected = _model.applySegment(
        outcome.endTissue,
        DecoSegment(
          startDepth: 18,
          endDepth: 0,
          durationSeconds: outcome.ttsAtBottom,
        ),
        _breathing(0.21, 0),
      );
      _expectSameTissues(outcome.surfacedTissue, expected as BuhlmannState);
    });

    test('includes the decompression stops', () {
      final outcome = engine.compute(
        _plan(depth: 45, bottomMinutes: 30, withO2: true),
      );

      expect(outcome.stops, isNotEmpty);
      // The schedule exists because the end tissue still owes deco; once it
      // is flown, nothing is owed.
      expect(_model.surfaceCeilingMeters(outcome.endTissue), greaterThan(0));
      expect(_model.surfaceCeilingMeters(outcome.surfacedTissue), 0);
      _expectSameTissues(outcome.surfacedTissue, _replaySchedule(outcome, 45));
    });

    test('breathes the break gas through a stop\'s air breaks', () {
      final outcome = engine.compute(
        _plan(
          depth: 45,
          bottomMinutes: 45,
          withO2: true,
          airBreaks: _airBreaks,
        ),
      );

      expect(outcome.stops.any((s) => s.airBreakSeconds > 0), isTrue);
      _expectSameTissues(
        outcome.surfacedTissue,
        _replaySchedule(outcome, 45, airBreaks: _airBreaks),
      );
      // Breathed on O2 throughout, the same stops leave a different state.
      final noBreaks = _replaySchedule(outcome, 45);
      expect(
        outcome.surfacedTissue.compartments.first.currentPN2,
        isNot(closeTo(noBreaks.compartments.first.currentPN2, 1e-6)),
      );
    });
  });
}
