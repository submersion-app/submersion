import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';

const _air = GasMix();
const _ean50 = GasMix(o2: 50);

/// A CCR plan whose open-circuit bailout carries air and EAN50, with a one
/// minute gas switch stop (issue #4160).
domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'bailout switch stop',
  mode: domain.PlanMode.ccr,
  gfLow: 30,
  gfHigh: 70,
  gasSwitchStopSeconds: 60,
  problemSolvingMinutes: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tanks: const [
    DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.bailout,
    ),
    DiveTank(
      id: 'ean50',
      volume: 11,
      startPressure: 200,
      gasMix: _ean50,
      role: TankRole.bailout,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: 45,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 45,
      durationMinutes: 12,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

void main() {
  test('a bailout ascent holds the EAN50 switch at 21 m and stays on the '
      'working ascent rate past it', () {
    final outcome = const BailoutSolver().solve(_plan())!;
    final stops = outcome.ocStops;

    final switchStop = stops.firstWhere((s) => s.depthMeters == 21);
    expect(switchStop.isGasSwitchOnly, isTrue);
    expect(switchStop.durationSeconds, 60);
    expect(switchStop.tankId, 'ean50');

    // The leg from the switch stop to the first deco stop is still the
    // working ascent (9 m/min by default), not the between-stops rate.
    final firstDeco = stops.firstWhere((s) => !s.isGasSwitchOnly);
    expect(firstDeco.depthMeters, lessThan(21));
    expect(
      firstDeco.arrivalRuntimeSeconds -
          (switchStop.arrivalRuntimeSeconds + switchStop.durationSeconds),
      ((21 - firstDeco.depthMeters) / 9 * 60).round(),
    );
  });
}
