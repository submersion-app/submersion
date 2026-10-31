import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

const _ean32 = GasMix(o2: 32);
const _ean40 = GasMix(o2: 40);
const _ean50 = GasMix(o2: 50);

const _supply = DiveTank(
  id: 'supply',
  volume: 12,
  startPressure: 230,
  gasMix: _ean32,
  role: TankRole.diluent,
);

/// Issue #3896's profile: 0 to 40 m at 18 m/min, then 35 minutes at 40 m.
List<PlanSegment> _segments({String tankId = 'supply'}) => [
  PlanSegment.travel(
    id: 'descent',
    fromDepth: 0,
    targetDepth: 40,
    tankId: tankId,
    gasMix: _ean32,
    order: 0,
    ratePerMinute: 18,
  ),
  PlanSegment.hold(
    id: 'bottom',
    depth: 40,
    durationMinutes: 35,
    tankId: tankId,
    gasMix: _ean32,
    order: 1,
  ),
];

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.scr,
  List<DiveTank> tanks = const [_supply],
  List<PlanSegment>? segments,
}) => domain.DivePlan(
  id: 'plan',
  name: 'Loop ascent',
  mode: mode,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  problemSolvingMinutes: 0,
  tanks: tanks,
  segments: segments ?? _segments(),
);

/// The rows the engine computed, past every authored leg.
List<PlanScheduleRow> _computedRows(PlanOutcome outcome, int authoredLegs) =>
    outcome.schedule.skip(authoredLegs).toList();

/// [plan]'s authored legs replayed on [breathing], then scheduled on [gases]
/// with the identical model: the numbers the engine owes for that ascent.
DecoSchedule _replay(
  domain.DivePlan plan,
  BreathingConfig breathing,
  AscentGasPlan gases,
) {
  final model = BuhlmannGf(
    gfLow: .3,
    gfHigh: .7,
    environment: PlanEngine.environmentFor(plan),
    policy: const SchedulePolicy(
      ascentRate: 9,
      intermediateAscentRate: 6,
      shallowAscentRate: 3,
      finalAscentRate: 1,
      lastStopDepth: 3,
      snapStopsToWholeMinutes: true,
    ),
  );
  var state = model.initial();
  for (final leg in const SegmentChain().resolve(plan.segments)) {
    state = model.applySegment(
      state,
      DecoSegment(
        startDepth: leg.startDepth,
        endDepth: leg.endDepth,
        durationSeconds: leg.durationSeconds,
      ),
      breathing,
    );
  }
  return model.schedule(state, currentDepth: 40, gases: gases);
}

void main() {
  const engine = PlanEngine();

  group('CMF SCR computed ascent (#3896)', () {
    test('owes the schedule of the loop, not of its richer supply gas', () {
      final outcome = engine.compute(_plan());

      // The issue's own reference: the same tissues scheduled by the same
      // model on the steady-state loop (FO2 23.7383%).
      expect(outcome.ttsAtBottom, 4980);
      expect(outcome.totalDecoSeconds, 4443);
    });

    test('the loop ppO2 carries straight on from the last authored leg', () {
      final outcome = engine.compute(_plan());
      final firstComputed = _computedRows(outcome, 2).first;

      expect(firstComputed.ppO2, closeTo(1.1769520850467288, 1e-9));
    });

    test('every computed line reads the supply gas with no gas switch', () {
      final outcome = engine.compute(_plan());
      final computed = _computedRows(outcome, 2);

      expect(computed, isNotEmpty);
      for (final row in computed) {
        expect(row.gasFO2, closeTo(0.32, 1e-9), reason: '${row.depthMeters} m');
        expect(row.gasFHe, 0.0, reason: '${row.depthMeters} m');
        expect(row.tankId, 'supply', reason: '${row.depthMeters} m');
        expect(row.gasSwitch, isFalse, reason: '${row.depthMeters} m');
      }
      for (final stop in outcome.stops) {
        expect(stop.gasFO2, closeTo(0.32, 1e-9));
        expect(stop.tankId, 'supply');
      }
    });

    test('the deco chart draws no gas switch on the loop', () {
      final plan = _plan();
      final series = buildCanvasSeries(
        plan: plan,
        outcome: engine.compute(plan),
        config: const PlanEngineConfig(),
      );

      expect(series.stopLabels, isNotEmpty);
      expect(series.gasSwitches, isEmpty);
    });

    test('carried bailout gas stays out of the ascent and is not charged', () {
      // Listed ahead of the supply, and one of them a twin of it: neither the
      // first-tank fallback nor a match on the mix may pick these.
      const twin = DiveTank(
        id: 'twin',
        volume: 12,
        startPressure: 230,
        gasMix: _ean32,
      );
      const rich = DiveTank(
        id: 'rich',
        volume: 12,
        startPressure: 230,
        gasMix: _ean50,
      );
      final plain = engine.compute(_plan());
      final outcome = engine.compute(_plan(tanks: const [twin, rich, _supply]));

      expect(outcome.ttsAtBottom, plain.ttsAtBottom);
      for (final row in _computedRows(outcome, 2)) {
        expect(row.tankId, 'supply', reason: '${row.depthMeters} m');
      }
      for (final stop in outcome.stops) {
        expect(stop.tankId, 'supply');
      }
      PlanTankUsage usage(String id) =>
          outcome.tankUsages.firstWhere((u) => u.tankId == id);
      expect(usage('twin').litersUsed, 0.0);
      expect(usage('rich').litersUsed, 0.0);
      expect(
        usage('supply').litersUsed,
        closeTo(plain.tankUsages.single.litersUsed, 1e-9),
      );
    });

    test('the ascent stays on the final leg\'s own supply gas', () {
      const second = DiveTank(
        id: 'second',
        volume: 12,
        startPressure: 230,
        gasMix: _ean40,
        role: TankRole.diluent,
      );
      final outcome = engine.compute(
        _plan(
          tanks: const [_supply, second],
          segments: [
            ..._segments(),
            PlanSegment.travel(
              id: 'up',
              fromDepth: 40,
              targetDepth: 30,
              tankId: 'second',
              gasMix: _ean40,
              order: 2,
              ratePerMinute: 9,
            ),
            PlanSegment.hold(
              id: 'shallower',
              depth: 30,
              durationMinutes: 5,
              tankId: 'second',
              gasMix: _ean40,
              order: 3,
            ),
          ],
        ),
      );

      final computed = _computedRows(outcome, 4);
      expect(computed, isNotEmpty);
      for (final row in computed) {
        expect(row.gasFO2, closeTo(0.40, 1e-9), reason: '${row.depthMeters} m');
        expect(row.tankId, 'second', reason: '${row.depthMeters} m');
      }
    });

    test('a final open-circuit leg is an explicit change: the ascent stays '
        'open circuit', () {
      const bailout = DiveTank(
        id: 'bailout',
        volume: 12,
        startPressure: 230,
        gasMix: _ean50,
      );
      final outcome = engine.compute(
        _plan(
          tanks: const [_supply, bailout],
          segments: [
            ..._segments(),
            PlanSegment.travel(
              id: 'up',
              fromDepth: 40,
              targetDepth: 21,
              tankId: 'supply',
              gasMix: _ean32,
              order: 2,
              ratePerMinute: 9,
            ),
            PlanSegment.hold(
              id: 'off-loop',
              depth: 21,
              durationMinutes: 2,
              tankId: 'bailout',
              gasMix: _ean50,
              diveModeOverride: domain.PlanMode.oc,
              order: 3,
            ),
          ],
        ),
      );

      expect(outcome.stops, isNotEmpty);
      for (final stop in outcome.stops) {
        expect(stop.gasFO2, closeTo(0.50, 1e-9));
        expect(stop.tankId, 'bailout');
      }
    });

    test('stops accumulate oxygen exposure at the loop ppO2', () {
      const config = PlanEngineConfig();
      final outcome = engine.compute(_plan());
      final calculator = O2ToxicityCalculator(
        ppO2WarningThreshold: config.ppO2Working,
        ppO2CriticalThreshold: config.ppO2Deco,
        cnsWarningThreshold: config.cnsWarningThreshold,
        cnsMethod: config.cnsMethod,
      );
      final environment = PlanEngine.environmentFor(_plan());
      final loop = Scr(supplyFO2: 0.32, injectionRateLpm: 12);
      var expected = outcome.segmentOutcomes.last.cns;
      for (final stop in outcome.stops) {
        expected += calculator.calculateCnsForSegment(
          loop.inspiredAt(environment.pressureAtDepth(stop.depthMeters)).pO2,
          stop.durationSeconds,
        );
      }

      expect(outcome.cnsEnd, closeTo(expected, 1e-9));
    });

    test('a CCR stop accumulates oxygen exposure at the setpoint', () {
      const config = PlanEngineConfig();
      final plan = _plan(mode: domain.PlanMode.ccr);
      final outcome = engine.compute(plan);
      final calculator = O2ToxicityCalculator(
        ppO2WarningThreshold: config.ppO2Working,
        ppO2CriticalThreshold: config.ppO2Deco,
        cnsWarningThreshold: config.cnsWarningThreshold,
        cnsMethod: config.cnsMethod,
      );
      final resolved = config.resolvedFor(plan);
      final loop = CcrLoopAscentGas(
        environment: PlanEngine.environmentFor(plan),
        setpointLow: resolved.setpointLowFor(plan),
        setpointHigh: resolved.setpointHighFor(plan),
        switchDepth: plan.effectiveSetpointSwitchDepth,
        diluentFO2: 0.32,
      );
      var expected = outcome.segmentOutcomes.last.cns;
      for (final stop in outcome.stops) {
        expected += calculator.calculateCnsForSegment(
          loop.inspiredPpO2At(stop.depthMeters),
          stop.durationSeconds,
        );
      }

      expect(outcome.stops, isNotEmpty);
      expect(outcome.cnsEnd, closeTo(expected, 1e-9));
    });

    test('the ceiling replay clears on the same loop the schedule used', () {
      final outcome = engine.compute(_plan());

      expect(outcome.ceilingTrace.last.$2, 0.0);
    });

    test('asks for bailout gas, not a deco gas the loop would never use', () {
      List<PlanIssueType> types(PlanOutcome outcome) => [
        for (final issue in outcome.issues) issue.type,
      ];
      const bailout = DiveTank(
        id: 'bailout',
        volume: 12,
        startPressure: 230,
        gasMix: _ean50,
      );

      final bare = types(engine.compute(_plan()));
      expect(bare, contains(PlanIssueType.noBailoutCarried));
      expect(bare, isNot(contains(PlanIssueType.ndlExceededNoDecoGas)));

      final carried = types(
        engine.compute(_plan(tanks: const [_supply, bailout])),
      );
      expect(carried, isNot(contains(PlanIssueType.noBailoutCarried)));
      expect(carried, isNot(contains(PlanIssueType.ndlExceededNoDecoGas)));
    });

    test('a supply nobody marked as diluent is not its own bailout', () {
      const unmarked = DiveTank(
        id: 'supply',
        volume: 12,
        startPressure: 230,
        gasMix: _ean32,
      );
      final outcome = engine.compute(_plan(tanks: const [unmarked]));

      expect([
        for (final issue in outcome.issues) issue.type,
      ], contains(PlanIssueType.noBailoutCarried));
    });
  });

  group('pSCR computed ascent (#3896)', () {
    domain.DivePlan pscrPlan() => _plan(mode: domain.PlanMode.pscr);

    PassiveScr loop() => PassiveScr(supplyFO2: 0.32);

    test('owes more than the same tissues ascending on the supply gas', () {
      final plan = pscrPlan();
      final outcome = engine.compute(plan);
      final onSupply = _replay(plan, loop(), FixedAscentGas(fN2: 0.68));

      expect(outcome.ttsAtBottom, greaterThan(onSupply.ttsSeconds));
    });

    test('every computed line reads the supply gas at the loop ppO2', () {
      final plan = pscrPlan();
      final outcome = engine.compute(plan);
      final environment = PlanEngine.environmentFor(plan);

      for (final row in _computedRows(outcome, 2)) {
        expect(row.gasFO2, closeTo(0.32, 1e-9), reason: '${row.depthMeters} m');
        expect(row.tankId, 'supply', reason: '${row.depthMeters} m');
        expect(row.gasSwitch, isFalse, reason: '${row.depthMeters} m');
      }
      final stopRows = outcome.schedule.where(
        (r) => r.kind == PlanScheduleRowKind.stop,
      );
      expect(stopRows, isNotEmpty);
      for (final row in stopRows) {
        expect(
          row.ppO2,
          closeTo(
            loop().inspiredAt(environment.pressureAtDepth(row.depthMeters)).pO2,
            1e-9,
          ),
          reason: '${row.depthMeters} m',
        );
      }
    });

    test('the loop drifting with depth is not a gas switch', () {
      final free = engine.compute(pscrPlan());
      final floored = const PlanEngine(
        config: PlanEngineConfig(gasSwitchStopSeconds: 180),
      ).compute(pscrPlan());

      expect(floored.ttsAtBottom, free.ttsAtBottom);
      expect(
        [for (final stop in floored.stops) stop.durationSeconds],
        [for (final stop in free.stops) stop.durationSeconds],
      );
    });

    test('a loop hypoxic near the surface still schedules on real numbers', () {
      // On air the metabolic drop exceeds the supply ppO2 near the surface,
      // so the loop's ppO2 clamps at zero while its effective fraction would
      // go below it.
      const air = GasMix(o2: 21);
      const airTank = DiveTank(
        id: 'supply',
        volume: 12,
        startPressure: 230,
        gasMix: air,
        role: TankRole.diluent,
      );
      final outcome = engine.compute(
        _plan(
          mode: domain.PlanMode.pscr,
          tanks: const [airTank],
          segments: [
            PlanSegment.travel(
              id: 'descent',
              fromDepth: 0,
              targetDepth: 30,
              tankId: 'supply',
              gasMix: air,
              order: 0,
              ratePerMinute: 18,
            ),
            PlanSegment.hold(
              id: 'bottom',
              depth: 30,
              durationMinutes: 40,
              tankId: 'supply',
              gasMix: air,
              order: 1,
            ),
          ],
        ),
      );

      expect(outcome.stops, isNotEmpty);
      for (final stop in outcome.stops) {
        expect(stop.gasFO2, closeTo(0.21, 1e-9));
      }
      for (final row in _computedRows(outcome, 2)) {
        expect(row.ppO2, greaterThanOrEqualTo(0.0));
        expect(row.gasFO2, closeTo(0.21, 1e-9));
      }
    });
  });
}
