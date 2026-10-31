import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_markers.dart';

const _air = GasMix(o2: 21);
const _o2 = GasMix(o2: 100);

const _diluentTank = DiveTank(
  id: 'dil',
  gasMix: _air,
  role: TankRole.diluent,
  volume: 3,
  startPressure: 200,
);
const _loopO2Tank = DiveTank(
  id: 'loopO2',
  gasMix: _o2,
  role: TankRole.oxygenSupply,
  volume: 3,
  startPressure: 200,
);

DiveTank _bailoutO2({double volume = 7, double? modMeters}) => DiveTank(
  id: 'bailO2',
  gasMix: _o2,
  role: TankRole.bailout,
  volume: volume,
  startPressure: 200,
  decoSwitchDepth: modMeters,
);

const _bailoutAir = DiveTank(
  id: 'bailAir',
  gasMix: _air,
  role: TankRole.bailout,
  volume: 11,
  startPressure: 200,
);

List<PlanSegment> _toDepth(double depth, {int minutes = 20}) => [
  PlanSegment.travel(
    id: 'down',
    fromDepth: 0,
    targetDepth: depth,
    ratePerMinute: 18,
    tankId: 'dil',
    gasMix: _air,
    order: 0,
  ),
  PlanSegment.hold(
    id: 'bottom',
    depth: depth,
    durationMinutes: minutes,
    tankId: 'dil',
    gasMix: _air,
    order: 1,
  ),
];

domain.DivePlan _plan({
  List<DiveTank>? bailouts,
  List<PlanSegment>? segments,
  domain.PlanMode mode = domain.PlanMode.ccr,
}) => domain.DivePlan(
  id: 'oxygen-only',
  name: 'Only shallow bailout',
  mode: mode,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  problemSolvingMinutes: 0,
  tanks: [
    _diluentTank,
    _loopO2Tank,
    ...bailouts ?? [_bailoutO2()],
  ],
  segments: segments ?? _toDepth(20),
);

void main() {
  const config = PlanEngineConfig(gasModel: GasModel.ideal);
  const solver = BailoutSolver(config: config);
  const engine = PlanEngine(config: config);

  group('BailoutSolver (issue #3961)', () {
    test('no gas at the failure depth is reported, not passed as sufficient: '
        '100% O2 from 20 m has an ample cylinder and no valid ascent', () {
      final outcome = solver.solve(_plan())!;

      expect(outcome.gasGap, isNotNull);
      expect(outcome.gasGap!.depthMeters, 20);
      expect(outcome.gasGap!.deepestModMeters, closeTo(6, 0.1));
      expect(outcome.sufficient, isFalse);
    });

    test('more of the same shallow gas never closes the gap', () {
      final outcome = solver.solve(_plan(bailouts: [_bailoutO2(volume: 100)]))!;

      expect(outcome.gasGap, isNotNull);
      expect(outcome.sufficient, isFalse);
    });

    test('a carried gas that reaches the failure depth closes the gap, and '
        'the shallow oxygen stays on the plan for the stops', () {
      final outcome = solver.solve(
        _plan(bailouts: [_bailoutAir, _bailoutO2()]),
      )!;

      expect(outcome.gasGap, isNull);
      expect(outcome.sufficient, isTrue);
    });

    test('a spike past every MOD is a gap even when the worst-case liters '
        'come from a longer, shallower hold the gas does cover', () {
      final outcome = solver.solve(
        _plan(
          bailouts: [_bailoutO2(volume: 30)],
          segments: [
            ..._toDepth(5, minutes: 40),
            PlanSegment.travel(
              id: 'spike-down',
              fromDepth: 5,
              targetDepth: 9,
              ratePerMinute: 18,
              tankId: 'dil',
              gasMix: _air,
              order: 2,
            ),
            PlanSegment.travel(
              id: 'spike-up',
              fromDepth: 9,
              targetDepth: 5,
              ratePerMinute: 9,
              tankId: 'dil',
              gasMix: _air,
              order: 3,
            ),
          ],
        ),
      )!;

      expect(outcome.gasGap?.depthMeters, 9);
      expect(outcome.sufficient, isFalse);
    });

    test('a MOD set by hand is the diver\'s call and counts as covering', () {
      final outcome = solver.solve(
        _plan(bailouts: [_bailoutO2(modMeters: 20)]),
      )!;

      expect(outcome.gasGap, isNull);
    });

    test('a failure exactly at the deepest MOD has a gas', () {
      final outcome = solver.solve(
        _plan(bailouts: [_bailoutO2()], segments: _toDepth(6)),
      )!;

      expect(outcome.gasGap, isNull);
    });

    test('every loop mode gets the check, not CCR alone', () {
      // Not oxygen: SCR reads a pure-O2 cylinder as supply, not bailout.
      const ean80 = DiveTank(
        id: 'bailEan80',
        gasMix: GasMix(o2: 80),
        role: TankRole.bailout,
        volume: 7,
        startPressure: 200,
      );

      for (final mode in [domain.PlanMode.scr, domain.PlanMode.pscr]) {
        final outcome = solver.solve(_plan(mode: mode, bailouts: [ean80]))!;

        expect(outcome.gasGap, isNotNull, reason: mode.name);
      }
    });
  });

  group('PlanEngine noEligibleBailoutGas (issue #3961)', () {
    Iterable<PlanIssue> gapIssues(PlanOutcome outcome) => outcome.issues.where(
      (issue) => issue.type == PlanIssueType.noEligibleBailoutGas,
    );

    test('raises an alert naming the depth and the deepest MOD carried, on a '
        'plan with no deco of its own', () {
      final outcome = engine.compute(_plan());

      final issue = gapIssues(outcome).single;
      expect(issue.severity, PlanIssueSeverity.alert);
      expect(issue.atDepth, 20);
      expect(issue.value, 20);
      expect(issue.threshold, closeTo(6, 0.1));
      expect(outcome.stops, isEmpty);
    });

    test('agrees with the solver on the MOD it reports', () {
      final plan = _plan();

      expect(
        gapIssues(engine.compute(plan)).single.threshold,
        solver.solve(plan)!.gasGap!.deepestModMeters,
      );
    });

    test('a MOD set by hand clears the alert, as it clears the solver gap', () {
      final outcome = engine.compute(
        _plan(bailouts: [_bailoutO2(modMeters: 20)]),
      );

      expect(gapIssues(outcome), isEmpty);
    });

    test('starts where the descent passes the deepest MOD, so the profile '
        'can mark it', () {
      final outcome = engine.compute(_plan());

      // 18 m/min, so about 6 m takes about 20 seconds.
      final start = gapIssues(outcome).single.atRuntime;
      expect(start, closeTo(20, 2));
      expect(
        planIssueMarkers(outcome.issues).map((m) => m.runtimeSeconds),
        contains(start),
      );
    });

    test('a plan told it carries no bailout gas hears nothing about a MOD: '
        'the loop\'s own supply is not a bailout gas', () {
      const ean40 = GasMix(o2: 40);
      final outcome = engine.compute(
        _plan(
          mode: domain.PlanMode.scr,
          bailouts: const [
            DiveTank(
              id: 'supply',
              gasMix: ean40,
              volume: 11,
              startPressure: 200,
            ),
          ],
          segments: [
            PlanSegment.travel(
              id: 'down',
              fromDepth: 0,
              targetDepth: 35,
              ratePerMinute: 18,
              tankId: 'supply',
              gasMix: ean40,
              order: 0,
            ),
            PlanSegment.hold(
              id: 'bottom',
              depth: 35,
              durationMinutes: 60,
              tankId: 'supply',
              gasMix: ean40,
              order: 1,
            ),
          ],
        ),
      );

      final types = outcome.issues.map((issue) => issue.type);
      expect(types, contains(PlanIssueType.noBailoutCarried));
      expect(types, isNot(contains(PlanIssueType.noEligibleBailoutGas)));
    });

    test('an alert leaves the plan itself diveable', () {
      expect(engine.compute(_plan()).isDiveable, isTrue);
    });

    test('clears once a carried gas reaches the bottom', () {
      final outcome = engine.compute(
        _plan(bailouts: [_bailoutAir, _bailoutO2()]),
      );

      expect(gapIssues(outcome), isEmpty);
    });

    test('a plan with no bailout tank leaves that to noBailoutCarried', () {
      final outcome = engine.compute(_plan(bailouts: const []));

      expect(gapIssues(outcome), isEmpty);
    });

    test('an open-circuit plan has no loop to bail out of', () {
      final outcome = engine.compute(_plan(mode: domain.PlanMode.oc));

      expect(gapIssues(outcome), isEmpty);
    });
  });
}
