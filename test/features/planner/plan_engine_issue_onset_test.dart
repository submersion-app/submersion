import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Every issue that happens at a moment in the dive carries the runtime it
/// starts at, so the chart can mark it on the profile (#3738).

const _air = GasMix(o2: 21);
const _ean32 = GasMix(o2: 32);

domain.DivePlan _plan({
  required GasMix gas,
  double depth = 40,
  int minutes = 20,
  double volume = 24,
  double startPressure = 232,
  double reservePressure = 50,
  double descentRate = 20,
  List<DiveTank> extraTanks = const [],
}) => domain.DivePlan(
  id: 'plan-onset',
  name: 'Onset',
  gfLow: 40,
  gfHigh: 80,
  reservePressure: reservePressure,
  tanks: [
    DiveTank(
      id: 'back',
      volume: volume,
      startPressure: startPressure,
      gasMix: gas,
    ),
    ...extraTanks,
  ],
  segments: [
    PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: depth,
      tankId: 'back',
      gasMix: gas,
      order: 0,
      ratePerMinute: descentRate,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'back',
      gasMix: gas,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026, 10, 28),
  updatedAt: DateTime(2026, 10, 28),
);

PlanIssue _issue(PlanOutcome outcome, PlanIssueType type) =>
    outcome.issues.firstWhere((i) => i.type == type);

/// A CCR plan, for the legs a per-segment override takes off the loop.
domain.DivePlan _ccrPlan({
  required List<DiveTank> tanks,
  required List<PlanSegment> segments,
  double reservePressure = 50,
}) => domain.DivePlan(
  id: 'plan-ccr-onset',
  name: 'CCR onset',
  mode: domain.PlanMode.ccr,
  problemSolvingMinutes: 0,
  reservePressure: reservePressure,
  tanks: tanks,
  segments: segments,
  createdAt: DateTime(2026, 10, 28),
  updatedAt: DateTime(2026, 10, 28),
);

const _diluent = DiveTank(
  id: 'dil',
  volume: 3,
  startPressure: 200,
  gasMix: _air,
  role: TankRole.diluent,
);

const _oxygen = DiveTank(
  id: 'o2',
  volume: 3,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
);

void main() {
  const engine = PlanEngine();

  test('ppO2 starts where the descent passes the working limit', () {
    // EAN32 reaches ppO2 1.4 at 33.75 m; descending at 20 m/min that is
    // 101 s into the dive, well before the 120 s descent ends.
    final outcome = engine.compute(_plan(gas: _ean32, depth: 37));
    final issue = _issue(outcome, PlanIssueType.ppO2High);
    expect(issue.atRuntime, closeTo(100, 2));
    // The message still names the deepest point of the leg.
    expect(issue.atDepth, 37);
  });

  test('a ppO2 limit is passed where the plan\'s own water puts it', () {
    // At altitude in fresh water 1.4 bar on EAN32 sits about 4 m deeper than
    // 10 m per bar says, and the warning itself is judged in this water.
    final plan = _plan(
      gas: _ean32,
    ).copyWith(altitude: 3000.0, salinityPpt: 0.0);
    final environment = PlanEngine.environmentFor(plan);
    final surface = environment.pressureAtDepth(0);
    final barPerMeter = (environment.pressureAtDepth(10) - surface) / 10;
    final limitDepth = (1.4 / 0.32 - surface) / barPerMeter;

    final issue = engine
        .compute(plan)
        .issues
        .firstWhere(
          (i) => i.type == PlanIssueType.ppO2High && i.segmentId == 'down',
        );
    // Three seconds a metre at 20 m/min.
    expect(issue.atRuntime, closeTo(limitDepth * 3, 2));
  });

  test('a level leg already over the limit starts at the leg', () {
    final outcome = engine.compute(_plan(gas: _ean32, depth: 37));
    final onBottom = outcome.issues.where(
      (i) => i.type == PlanIssueType.ppO2High && i.segmentId == 'bottom',
    );
    expect(onBottom.single.atRuntime, 111);
  });

  test('END starts where the descent passes the END limit', () {
    // Air's END equals its depth, so the 30 m limit is passed 90 s down.
    final outcome = engine.compute(_plan(gas: _air));
    final issue = _issue(outcome, PlanIssueType.endExceeded);
    expect(issue.atRuntime, closeTo(90, 2));
  });

  test('CNS starts where the running total reaches the threshold', () {
    // EAN40 at 25 m is ppO2 1.4, about 0.67 % CNS a minute.
    final outcome = engine.compute(
      _plan(gas: const GasMix(o2: 40), depth: 25, minutes: 130),
    );
    final issue = outcome.issues.firstWhere(
      (i) =>
          i.type == PlanIssueType.cnsWarning ||
          i.type == PlanIssueType.cnsCritical,
    );
    expect(issue.atRuntime, isNotNull);
    expect(issue.atRuntime, greaterThan(0));
    expect(issue.atRuntime, lessThan(outcome.runtimeSeconds));
  });

  group('the computed ascent', () {
    // Ends on oxygen, so even the last leg to the surface adds OTU.
    final plan = _plan(
      gas: _air,
      extraTanks: const [
        DiveTank(
          id: 'oxygen',
          volume: 7,
          startPressure: 200,
          gasMix: GasMix(o2: 100),
          role: TankRole.deco,
        ),
      ],
    );

    PlanIssue otuIssueWithLimit(double limit) => _issue(
      PlanEngine(config: PlanEngineConfig(otuLimit: limit)).compute(plan),
      PlanIssueType.otuHigh,
    );

    test('adds its travel to the exposure where the plan leaves off', () {
      final authored = engine.compute(plan).segmentOutcomes.last;
      // Just past what the authored legs reach, so only the ascent gets there.
      final issue = otuIssueWithLimit(authored.otu + 0.001);
      expect(issue.atRuntime, closeTo(authored.endRuntime, 2));
    });

    test('adds the leg to the surface after the last stop', () {
      final outcome = engine.compute(plan);
      expect(outcome.stops, isNotEmpty);
      final issue = otuIssueWithLimit(outcome.otuTotal - 0.001);
      expect(issue.atRuntime, closeTo(outcome.runtimeSeconds, 2));
    });

    test('draws a deco gas from the moment the diver switches to it', () {
      const ean50 = GasMix(o2: 50);
      final outcome = engine.compute(
        _plan(
          gas: _air,
          reservePressure: 199.9,
          extraTanks: const [
            DiveTank(
              id: 'stage',
              volume: 7,
              startPressure: 200,
              gasMix: ean50,
              role: TankRole.deco,
            ),
          ],
        ),
      );
      final firstOnStage = outcome.schedule.firstWhere(
        (row) => row.gasFO2 == 0.5,
      );
      final issue = outcome.issues.firstWhere(
        (i) =>
            i.type == PlanIssueType.gasReserveViolation && i.tankId == 'stage',
      );
      expect(
        issue.atRuntime,
        closeTo(firstOnStage.runtimeSeconds - firstOnStage.durationSeconds, 2),
      );
    });
  });

  test('running out of gas starts before the dive ends, on its tank', () {
    final outcome = engine.compute(
      _plan(gas: _air, depth: 30, volume: 3, startPressure: 100),
    );
    final issue = _issue(outcome, PlanIssueType.gasOut);
    expect(issue.tankId, 'back');
    expect(issue.segmentId, isNull);
    expect(issue.atRuntime, isNotNull);
    expect(issue.atRuntime, lessThan(outcome.runtimeSeconds));
  });

  test('the reserve is reached before the tank would run dry', () {
    final outcome = engine.compute(
      _plan(gas: _air, depth: 30, minutes: 10, reservePressure: 200),
    );
    final issue = _issue(outcome, PlanIssueType.gasReserveViolation);
    expect(issue.tankId, 'back');
    // 232 bar down to 200 bar on a 24 L twinset takes a few minutes on
    // the bottom, not the whole dive.
    expect(issue.atRuntime, greaterThan(0));
    expect(issue.atRuntime, lessThan(outcome.runtimeSeconds));
  });

  test('a hand-set MOD over its limit starts at the switch to that gas', () {
    const back = GasMix(o2: 15, he: 55);
    const ean40 = GasMix(o2: 40);
    final plan = _plan(gas: back, depth: 70, minutes: 25).copyWith(
      tanks: const [
        DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: back),
        DiveTank(
          id: 'ean40',
          volume: 11.1,
          startPressure: 207,
          gasMix: ean40,
          decoSwitchDepth: 33,
        ),
      ],
    );
    final outcome = engine.compute(plan);
    final switchRow = outcome.schedule.firstWhere(
      (r) => r.tankId == 'ean40' && r.gasSwitch,
    );
    final issue = outcome.issues.firstWhere(
      (i) => i.type == PlanIssueType.ppO2Critical && i.atDepth == 33,
    );
    // 33 m has no stop of its own, so the diver switches partway up the leg
    // folded into the first line on that gas, not when that line starts.
    final onEan40 = switchRow.foldedTravel.last;
    expect(onEan40.tankId, 'ean40');
    expect(onEan40.fromDepthMeters, 33);
    expect(issue.atRuntime, switchRow.startRuntimeSeconds - onEan40.seconds);
  });

  test('a deco ppO2 issue starts where its own ceiling is passed', () {
    // With a 4 m maximum depth for pure O2, oxygen is over its deco ceiling
    // from 4 m, though its ppO2 there (1.4 bar) is under the flat 1.6 bar
    // ceiling it would pass only at 6 m. Descending 8 m in 60 s puts 4 m
    // at 30 s, not 45 s.
    const engineWithO2Depth = PlanEngine(
      config: PlanEngineConfig(maxO2DepthEnabled: true, maxO2DepthMeters: 4),
    );
    final outcome = engineWithO2Depth.compute(
      _plan(gas: const GasMix(o2: 100), depth: 8, minutes: 5, descentRate: 8),
    );
    final issue = outcome.issues.firstWhere(
      (i) => i.type == PlanIssueType.ppO2Critical && i.segmentId == 'down',
    );
    expect(issue.atRuntime, closeTo(30, 2));
  });

  test('problem-solving gas counts from where the bottom ends', () {
    // The gas is charged once every authored leg is, yet the diver needs it
    // in hand on leaving the bottom, so the ascent after it must not be read
    // first. The reserve here falls between the bottom's end and the ascent's.
    final outcome = engine.compute(
      domain.DivePlan(
        id: 'plan-lump',
        name: 'Lump',
        gfLow: 40,
        gfHigh: 80,
        reservePressure: 213,
        problemSolvingMinutes: 4,
        tanks: const [
          DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _air),
        ],
        segments: [
          PlanSegment.travel(
            id: 'down',
            fromDepth: 0,
            targetDepth: 30,
            tankId: 'back',
            gasMix: _air,
            order: 0,
            ratePerMinute: 20,
          ),
          PlanSegment.hold(
            id: 'bottom',
            depth: 30,
            durationMinutes: 5,
            tankId: 'back',
            gasMix: _air,
            order: 1,
          ),
          PlanSegment.travel(
            id: 'up',
            fromDepth: 30,
            targetDepth: 10,
            tankId: 'back',
            gasMix: _air,
            order: 2,
            ratePerMinute: 10,
          ),
        ],
        createdAt: DateTime(2026, 10, 28),
        updatedAt: DateTime(2026, 10, 28),
      ),
    );
    expect(_issue(outcome, PlanIssueType.gasReserveViolation).atRuntime, 390);
  });

  group('a CCR plan with a leg off the loop', () {
    final descent = PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: 30,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    );

    test('a hypoxic gas is judged on what that leg breathes', () {
      // The plan's setpoint would keep the loop well oxygenated, but this
      // leg is breathed off a 10% cylinder: under 0.16 bar above about 6 m.
      const hypoxic = GasMix(o2: 10, he: 50);
      final outcome = engine.compute(
        _ccrPlan(
          tanks: const [
            _diluent,
            _oxygen,
            DiveTank(
              id: 'bo',
              volume: 12,
              startPressure: 200,
              gasMix: hypoxic,
              role: TankRole.bailout,
            ),
          ],
          segments: [
            descent,
            PlanSegment.travel(
              id: 'up',
              fromDepth: 30,
              targetDepth: 3,
              tankId: 'bo',
              gasMix: hypoxic,
              order: 1,
              ratePerMinute: 9,
              diveModeOverride: domain.PlanMode.oc,
            ),
          ],
        ),
      );
      final issue = _issue(outcome, PlanIssueType.hypoxicGas);
      expect(issue.segmentId, 'up');
      // 100 s down, then 24 m of the 27 m ascent's 180 s.
      expect(issue.atRuntime, closeTo(260, 10));
    });

    test('a cylinder breathed off the loop runs out during that leg', () {
      final outcome = engine.compute(
        _ccrPlan(
          tanks: const [
            _diluent,
            _oxygen,
            DiveTank(
              id: 'bo',
              volume: 3,
              startPressure: 100,
              gasMix: _air,
              role: TankRole.bailout,
            ),
          ],
          segments: [
            descent,
            PlanSegment.hold(
              id: 'off-loop',
              depth: 30,
              durationMinutes: 20,
              tankId: 'bo',
              gasMix: _air,
              order: 1,
              diveModeOverride: domain.PlanMode.oc,
            ),
          ],
        ),
      );
      final issue = _issue(outcome, PlanIssueType.gasOut);
      expect(issue.tankId, 'bo');
      // About 300 L at 15 L/min and 4 bar: five minutes into the leg.
      expect(issue.atRuntime, closeTo(100 + 300, 30));
    });

    test('metabolic O2 stops counting while the diver is off the loop', () {
      final outcome = engine.compute(
        _ccrPlan(
          tanks: const [
            _diluent,
            DiveTank(
              id: 'o2',
              volume: 0.5,
              startPressure: 100,
              gasMix: GasMix(o2: 100),
              role: TankRole.oxygenSupply,
            ),
            DiveTank(
              id: 'bo',
              volume: 24,
              startPressure: 200,
              gasMix: _air,
              role: TankRole.bailout,
            ),
          ],
          segments: [
            PlanSegment.travel(
              id: 'down',
              fromDepth: 0,
              targetDepth: 6,
              tankId: 'dil',
              gasMix: _air,
              order: 0,
              ratePerMinute: 18,
            ),
            PlanSegment.hold(
              id: 'on-loop',
              depth: 6,
              durationMinutes: 5,
              tankId: 'dil',
              gasMix: _air,
              order: 1,
            ),
            PlanSegment.hold(
              id: 'off-loop',
              depth: 6,
              durationMinutes: 30,
              tankId: 'bo',
              gasMix: _air,
              order: 2,
              diveModeOverride: domain.PlanMode.oc,
            ),
            PlanSegment.hold(
              id: 'back-on-loop',
              depth: 6,
              durationMinutes: 30,
              tankId: 'dil',
              gasMix: _air,
              order: 3,
            ),
          ],
        ),
      );
      final issue = _issue(outcome, PlanIssueType.gasReserveViolation);
      expect(issue.tankId, 'o2');
      // 50 bar of O2 in 0.5 L is about 26 L, so 26 minutes on the loop at
      // 1 L/min: the first 5 and 21 of the last 30, with the half hour off
      // it in between.
      expect(issue.atRuntime, closeTo(20 + 300 + 1800 + 1260, 60));
    });
  });

  test('a missing deco gas has no moment of its own', () {
    final outcome = engine.compute(_plan(gas: _air, depth: 45, minutes: 25));
    final issue = _issue(outcome, PlanIssueType.ndlExceededNoDecoGas);
    expect(issue.atRuntime, isNull);
  });
}
