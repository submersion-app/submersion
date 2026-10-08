import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);

const _back = DiveTank(
  id: 'back',
  volume: 40,
  startPressure: 230,
  gasMix: _air,
  role: TankRole.backGas,
);

domain.DivePlan _plan({List<DiveTank> tanks = const [_back]}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'Gas rules',
      gfLow: 40,
      gfHigh: 80,
      descentRate: 18,
      ascentRate: 9,
      sacBottom: 15,
      reservePressure: 50,
      salinityPpt: DiveEnvironment.salinityPptFromDensity(
        DiveEnvironment.en13319Density,
      ),
      tanks: tanks,
      createdAt: DateTime(2026, 9, 25),
      updatedAt: DateTime(2026, 9, 25),
    );

/// Descend to 20 m (67 s) and hold 600 s: failure at 667 s, well inside
/// the no-decompression limit, so the ascent is one row straight up.
final _outbound = [
  PlanSegment.travel(
    id: 'down',
    fromDepth: 0,
    targetDepth: 20,
    tankId: 'back',
    gasMix: _air,
    ratePerMinute: 18,
  ),
  const PlanSegment(
    id: 'hold',
    targetDepth: 20,
    durationSeconds: 600,
    tankId: 'back',
    gasMix: _air,
    order: 1,
  ),
];

ExitPathResult _run({
  required domain.DivePlan plan,
  required List<ExitDiver> divers,
  List<ExitLeg> legs = const [],
}) => const ExitPathEvaluator().evaluate(
  plan: plan,
  outboundSegments: _outbound,
  failureRuntimeSeconds: 667,
  exitLegs: legs,
  exitSpeedMps: 0.2,
  divers: divers,
);

void main() {
  group('reserve check', () {
    test('a cylinder the exit never breathes is not a shortfall', () {
      // A hypoxic trimix spare at 40 bar sits below the 50 bar reserve. It
      // is unbreathable near the surface, so the plan engine never switches
      // to it on the ascent (an air pony, by contrast, is breathed there).
      final result = _run(
        plan: _plan(
          tanks: const [
            _back,
            DiveTank(
              id: 'spare',
              volume: 3,
              startPressure: 40,
              gasMix: GasMix(o2: 10, he: 50),
              role: TankRole.stage,
            ),
          ],
        ),
        divers: const [ExitDiver(id: 'a', sacBottom: 15)],
      );
      expect(result.gasShortfallMemberIds, isEmpty);
    });

    test('a bailout cylinder is never held to the reserve', () {
      final result = _run(
        plan: _plan(
          tanks: const [
            _back,
            DiveTank(
              id: 'bail',
              volume: 7,
              startPressure: 30,
              gasMix: _air,
              role: TankRole.bailout,
            ),
          ],
        ),
        divers: const [ExitDiver(id: 'a', sacBottom: 15)],
      );
      expect(result.gasShortfallMemberIds, isEmpty);
    });
  });

  test('exit gas starts counting at the failure depth', () {
    // SAC 15 everywhere (the plan's deco SAC is 15 too), so the exit is the
    // whole dive's gas minus the outbound's, row for row.
    final plan = _plan();
    final result = _run(
      plan: plan,
      divers: const [ExitDiver(id: 'a', sacBottom: 15)],
    );
    final schedule = const PlanEngine()
        .compute(plan.copyWith(segments: _outbound))
        .schedule;
    final environment = PlanEngine.environmentFor(plan);
    const gas = MemberGasService();
    final whole = gas.litersByTank(
      rows: schedule,
      environment: environment,
      sacFor: (_) => 15,
    )['back']!;
    final outbound = gas.litersByTank(
      rows: [
        for (final row in schedule)
          if (row.runtimeSeconds <= 667) row,
      ],
      environment: environment,
      sacFor: (_) => 15,
    )['back']!;
    expect(result.exitLitersByMember['a'], closeTo(whole - outbound, 1e-6));
  });

  test('the ascent before the first stop is breathed at the working SAC', () {
    // No exit legs and no stop: the only exit row is the ascent from 20 m.
    // A stressed diver breathes more on it than a calm one with the same SAC.
    final result = _run(
      plan: _plan(),
      divers: const [
        ExitDiver(id: 'calm', sacBottom: 15),
        ExitDiver(id: 'stressed', sacBottom: 15, stressed: true),
      ],
    );
    expect(
      result.exitLitersByMember['stressed']!,
      greaterThan(result.exitLitersByMember['calm']!),
    );
  });

  test('an exit the plan engine calls not diveable is flagged', () {
    // EAN36 is fine at the 20 m failure depth (1.08 bar) but an exit leg at
    // 40 m breathes it at 1.8 bar, over the 1.6 bar critical limit.
    const ean36 = GasMix(o2: 36);
    final outbound = [
      PlanSegment.travel(
        id: 'down',
        fromDepth: 0,
        targetDepth: 20,
        tankId: 'back',
        gasMix: ean36,
        ratePerMinute: 18,
      ),
      const PlanSegment(
        id: 'hold',
        targetDepth: 20,
        durationSeconds: 600,
        tankId: 'back',
        gasMix: ean36,
        order: 1,
      ),
    ];
    ExitPathResult run(double exitDepth) => const ExitPathEvaluator().evaluate(
      plan: _plan(
        tanks: const [
          DiveTank(
            id: 'back',
            volume: 40,
            startPressure: 230,
            gasMix: ean36,
            role: TankRole.backGas,
          ),
        ],
      ),
      outboundSegments: outbound,
      failureRuntimeSeconds: 667,
      exitLegs: [
        ExitLeg(id: 'x', distanceM: 100, depthM: exitDepth, headingDeg: 0),
      ],
      exitSpeedMps: 0.2,
      divers: const [ExitDiver(id: 'a', sacBottom: 15)],
    );
    expect(run(40).notDiveable, isTrue);
    expect(run(20).notDiveable, isFalse);
  });

  group('stressed SAC is a multiple of the diver own SAC', () {
    test('the plan stressed-to-bottom ratio scales each diver', () {
      // Plan 15 L/min bottom, 37.5 stressed: a factor of 2.5.
      final plan = _plan();
      expect(ExitPathEvaluator.stressedSacFor(plan, 30), closeTo(75, 1e-9));
      expect(ExitPathEvaluator.stressedSacFor(plan, 12), closeTo(30, 1e-9));
    });

    test('stressed never means breathing less than normal', () {
      final plan = _plan().copyWith(sacStressed: 10);
      expect(ExitPathEvaluator.stressedSacFor(plan, 15), 15);
    });

    test('a plan with no bottom SAC falls back to the diver own SAC', () {
      final plan = _plan().copyWith(sacBottom: 0, sacStressed: 0);
      expect(ExitPathEvaluator.stressedSacFor(plan, 18), 18);
    });

    test('a stressed heavy breather is charged the scaled rate', () {
      // Stressed at 30 L/min own SAC means 75 L/min, exactly what a calm
      // diver whose own SAC is 75 breathes.
      final result = _run(
        plan: _plan(),
        divers: const [
          ExitDiver(id: 'heavy', sacBottom: 30, stressed: true),
          ExitDiver(id: 'reference', sacBottom: 75),
        ],
        legs: const [
          ExitLeg(id: 'x', distanceM: 100, depthM: 20, headingDeg: 180),
        ],
      );
      expect(
        result.exitLitersByMember['heavy'],
        closeTo(result.exitLitersByMember['reference']!, 1e-6),
      );
    });
  });
}
