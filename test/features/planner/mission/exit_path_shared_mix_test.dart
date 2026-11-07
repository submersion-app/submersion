import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/mission/exit_path_evaluator.dart';

/// An exit's deco is shared by every stage carrying its mix, so two small
/// stages that hold enough together are not a shortfall because the first
/// alone could not (#4138).
const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);

const _back = DiveTank(
  id: 'back',
  volume: 40,
  startPressure: 230,
  gasMix: _air,
  role: TankRole.backGas,
);

DiveTank _stage(String id) => DiveTank(
  id: id,
  volume: 2,
  startPressure: 230,
  gasMix: _ean50,
  role: TankRole.deco,
);

domain.DivePlan _plan(List<DiveTank> stages) => domain.DivePlan(
  id: 'plan-4138-exit',
  name: 'Shared stages',
  gfLow: 40,
  gfHigh: 80,
  descentRate: 18,
  ascentRate: 9,
  sacBottom: 15,
  sacDeco: 15,
  reservePressure: 50,
  problemSolvingMinutes: 0,
  salinityPpt: DiveEnvironment.salinityPptFromDensity(
    DiveEnvironment.en13319Density,
  ),
  tanks: [_back, ...stages],
  createdAt: DateTime(2026, 11, 7),
  updatedAt: DateTime(2026, 11, 7),
);

/// Descend to 40 m and hold 25 minutes on back gas: a decompression exit
/// whose shallow stops are breathed on EAN50.
final _outbound = [
  PlanSegment.travel(
    id: 'down',
    fromDepth: 0,
    targetDepth: 40,
    tankId: 'back',
    gasMix: _air,
    ratePerMinute: 18,
  ),
  const PlanSegment(
    id: 'hold',
    targetDepth: 40,
    durationSeconds: 1500,
    tankId: 'back',
    gasMix: _air,
    order: 1,
  ),
];

ExitPathResult _run(List<DiveTank> stages) =>
    const ExitPathEvaluator().evaluate(
      plan: _plan(stages),
      outboundSegments: _outbound,
      failureRuntimeSeconds: 1633,
      exitLegs: const [],
      exitSpeedMps: 0.2,
      divers: const [ExitDiver(id: 'a', sacBottom: 15)],
    );

void main() {
  test('one small stage alone cannot cover the exit deco', () {
    expect(_run([_stage('d1')]).gasShortfallMemberIds, {'a'});
  });

  test('two small stages of the mix cover it together', () {
    expect(_run([_stage('d1'), _stage('d2')]).gasShortfallMemberIds, isEmpty);
  });

  test('sharing moves no gas: the diver breathes the same total', () {
    final single = _run([_stage('d1')]);
    final pair = _run([_stage('d1'), _stage('d2')]);

    expect(
      pair.exitLitersByMember['a'],
      closeTo(single.exitLitersByMember['a']!, 1e-6),
    );
  });
}
