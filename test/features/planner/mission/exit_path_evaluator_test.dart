import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({double tankLiters = 40}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Exit path',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  sacBottom: 15,
  reservePressure: 50,
  salinityPpt: DiveEnvironment.salinityPptFromDensity(
    DiveEnvironment.en13319Density,
  ),
  tanks: [
    DiveTank(
      id: 'back',
      volume: tankLiters,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

/// Descend to 20 m (67 s) and hold 600 s: the failure point is at 667 s.
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

const _exitLeg = ExitLeg(id: 'x', distanceM: 300, depthM: 20, headingDeg: 180);

void main() {
  const evaluator = ExitPathEvaluator();

  ExitPathResult run({
    List<ExitLeg> legs = const [_exitLeg],
    double speed = 0.2,
    List<ExitDiver> divers = const [
      ExitDiver(id: 'a', sacBottom: 15),
      ExitDiver(id: 'b', sacBottom: 15, stressed: true),
    ],
    double tankLiters = 40,
  }) => evaluator.evaluate(
    plan: _plan(tankLiters: tankLiters),
    outboundSegments: _outbound,
    failureRuntimeSeconds: 667,
    exitLegs: legs,
    exitSpeedMps: speed,
    divers: divers,
  );

  test('the exit takes distance over speed and ends with an ascent', () {
    final result = run();
    expect(result.exitBottomSeconds, 1500);
    expect(result.ttsSeconds, greaterThan(0));
    expect(result.blockedByCurrent, isFalse);
  });

  test('a stressed diver breathes the stressed SAC on the exit bottom', () {
    final result = run();
    // 25 min at 3 bar: 1125 L at 15 L/min, 2812.5 L at 37.5 L/min; the
    // ascent is charged alike, so b is more than twice a.
    expect(
      result.exitLitersByMember['b']!,
      greaterThan(result.exitLitersByMember['a']! * 2),
    );
    expect(result.gasShortfallMemberIds, isEmpty);
  });

  test('no divers still yields the time, with nothing charged', () {
    final result = run(divers: const []);
    expect(result.exitBottomSeconds, 1500);
    expect(result.exitLitersByMember, isEmpty);
  });

  test('a current the exit speed cannot beat is blocked', () {
    final result = run(
      legs: const [
        ExitLeg(
          id: 'x',
          distanceM: 300,
          depthM: 20,
          headingDeg: 180,
          current: CurrentVector(speedMps: 0.3, setsTowardDeg: 0),
        ),
      ],
    );
    expect(result, ExitPathResult.blocked);
  });

  test('a leg shorter than the minimum is not travelled', () {
    final result = run(
      legs: const [ExitLeg(id: 'x', distanceM: 0.1, depthM: 20, headingDeg: 0)],
    );
    expect(result.exitBottomSeconds, 0);
    expect(result.blockedByCurrent, isFalse);
  });

  test('too little gas is a shortfall for every diver who runs out', () {
    expect(run(tankLiters: 3).gasShortfallMemberIds, {'a', 'b'});
  });
}
