import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/tissue_seed.dart';

/// Issue #3354: an authored ascent that goes shallower than the deco ceiling
/// skips the obligation, and the plan must say so.

const _air = GasMix(o2: 21);
const _tankId = 'tank-1';
const _airTank = DiveTank(
  id: _tankId,
  volume: 24.0,
  startPressure: 232,
  gasMix: _air,
);

PlanSegment _descent(double depth) => PlanSegment.travel(
  id: 'descent',
  fromDepth: 0,
  targetDepth: depth,
  tankId: _tankId,
  gasMix: _air,
  order: 0,
  ratePerMinute: 18.0,
);

PlanSegment _bottom(double depth, int minutes) => PlanSegment.hold(
  id: 'bottom',
  depth: depth,
  durationMinutes: minutes,
  tankId: _tankId,
  gasMix: _air,
  order: 1,
);

PlanSegment _ascentToSurface(double fromDepth, {int order = 2}) =>
    PlanSegment.travel(
      id: 'ascent',
      fromDepth: fromDepth,
      targetDepth: 0,
      tankId: _tankId,
      gasMix: _air,
      order: order,
      ratePerMinute: 9.0,
    );

domain.DivePlan _plan(List<PlanSegment> segments) => domain.DivePlan(
  id: 'plan-1',
  name: 'Ceiling test',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [_airTank],
  segments: segments,
  createdAt: DateTime(2026, 10, 16),
  updatedAt: DateTime(2026, 10, 16),
);

List<PlanIssue> _ceilingIssues(PlanOutcome outcome) => outcome.issues
    .where((i) => i.type == PlanIssueType.ceilingViolated)
    .toList();

void main() {
  const engine = PlanEngine();

  group('PlanEngine ceiling violation (#3354)', () {
    test('a deco dive ascending straight to the surface is flagged', () {
      final outcome = engine.compute(
        _plan([_descent(45), _bottom(45, 25), _ascentToSurface(45)]),
      );

      final issues = _ceilingIssues(outcome);
      expect(issues, hasLength(1));
      final issue = issues.single;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.segmentId, 'ascent');
      // The ceiling the diver went above, and the depth they were at.
      expect(issue.value, greaterThan(0));
      expect(issue.atDepth, lessThan(issue.value!));
      expect(outcome.isDiveable, isFalse);
    });

    test('the same dive left to the computed ascent is not flagged', () {
      final outcome = engine.compute(_plan([_descent(45), _bottom(45, 25)]));

      expect(outcome.stops, isNotEmpty);
      expect(_ceilingIssues(outcome), isEmpty);
    });

    test('authoring the computed ascent leg for leg is not flagged', () {
      // The engine's own ascent is the reference for "respects the
      // ceiling": typing it in as segments (travel to each stop, hold it,
      // then surface) must never raise the issue.
      final computed = engine.compute(_plan([_descent(45), _bottom(45, 25)]));
      expect(computed.stops, isNotEmpty);

      final segments = [_descent(45), _bottom(45, 25)];
      PlanSegment leg(String id, double depth, int seconds) => PlanSegment(
        id: id,
        targetDepth: depth,
        durationSeconds: seconds,
        tankId: _tankId,
        gasMix: _air,
        order: segments.length,
      );
      var legEnd = computed.segmentOutcomes.last.endRuntime;
      for (final (i, stop) in computed.stops.indexed) {
        segments
          ..add(
            leg('to-$i', stop.depthMeters, stop.arrivalRuntimeSeconds - legEnd),
          )
          ..add(leg('stop-$i', stop.depthMeters, stop.durationSeconds));
        legEnd = stop.arrivalRuntimeSeconds + stop.durationSeconds;
      }
      segments.add(leg('surface', 0, computed.runtimeSeconds - legEnd));

      final outcome = engine.compute(_plan(segments));
      expect(outcome.runtimeSeconds, computed.runtimeSeconds);
      expect(_ceilingIssues(outcome), isEmpty);
    });

    test('a no-deco dive ascending straight to the surface is not flagged', () {
      final outcome = engine.compute(
        _plan([_descent(18), _bottom(18, 20), _ascentToSurface(18)]),
      );

      expect(_ceilingIssues(outcome), isEmpty);
    });

    test('residual loading from a prior dive counts toward the ceiling', () {
      final segments = [_descent(18), _bottom(18, 20), _ascentToSurface(18)];
      final prior = BuhlmannAlgorithm(gfLow: 0.40, gfHigh: 0.80)
        ..calculateSegment(depthMeters: 40.0, durationSeconds: 45 * 60);
      final seeded = seededTissueState(
        compartments: prior.compartments,
        surfaceInterval: const Duration(minutes: 10),
        gfLow: 0.40,
        gfHigh: 0.80,
      );

      final fresh = engine.compute(_plan(segments));
      final repetitive = engine.compute(_plan(segments), startState: seeded);

      expect(_ceilingIssues(fresh), isEmpty);
      expect(_ceilingIssues(repetitive), isNotEmpty);
    });

    test('the breach check does not change the chart sampling', () {
      // Authored legs are checked at a finer slice than the chart draws;
      // the chart must still get one sample per 30 s of each leg plus the
      // leg's end, exactly as before.
      final outcome = engine.compute(
        _plan([_descent(45), _bottom(45, 25), _ascentToSurface(45)]),
      );
      final legEnds = {for (final s in outcome.segmentOutcomes) s.endRuntime};
      var legStart = 0;
      final expected = <int>[];
      for (final s in outcome.segmentOutcomes) {
        for (
          var t = legStart + PlanEngine.ceilingSampleSeconds;
          t < s.endRuntime;
          t += PlanEngine.ceilingSampleSeconds
        ) {
          expected.add(t);
        }
        expected.add(s.endRuntime);
        legStart = s.endRuntime;
      }
      final authoredSamples = outcome.ceilingTrace
          .map((p) => p.$1)
          .where((t) => t <= legEnds.reduce((a, b) => a > b ? a : b))
          .toList();
      expect(authoredSamples, expected);
    });

    test('the chart ceiling trace starts from the seeded tissues', () {
      final segments = [_descent(18), _bottom(18, 20)];
      final prior = BuhlmannAlgorithm(gfLow: 0.40, gfHigh: 0.80)
        ..calculateSegment(depthMeters: 40.0, durationSeconds: 45 * 60);
      final seeded = seededTissueState(
        compartments: prior.compartments,
        surfaceInterval: const Duration(minutes: 10),
        gfLow: 0.40,
        gfHigh: 0.80,
      );

      final fresh = engine.compute(_plan(segments));
      final repetitive = engine.compute(_plan(segments), startState: seeded);

      // A diver who surfaced owing deco ten minutes ago starts this dive
      // under a ceiling; a fresh diver does not.
      expect(fresh.ceilingTrace.first.$2, 0);
      expect(repetitive.ceilingTrace.first.$2, greaterThan(0));
    });
  });
}
