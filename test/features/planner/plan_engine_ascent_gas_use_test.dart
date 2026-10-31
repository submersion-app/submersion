import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix();
const _ean50 = GasMix(o2: 50);

void main() {
  const sacDeco = 12.0;

  domain.DivePlan noStopPlan() => domain.DivePlan(
    id: 'gas-use',
    name: 'Gas use',
    mode: domain.PlanMode.oc,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    problemSolvingMinutes: 0,
    sacBottom: 20,
    sacDeco: sacDeco,
    tanks: const [
      DiveTank(id: 'back', volume: 12, startPressure: 200, gasMix: _air),
      DiveTank(
        id: 'deco',
        volume: 7,
        startPressure: 200,
        gasMix: _ean50,
        role: TankRole.deco,
      ),
    ],
    segments: [
      PlanSegment.travel(
        id: 'descent',
        fromDepth: 0,
        targetDepth: 30,
        tankId: 'back',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: 'bottom',
        depth: 30,
        durationMinutes: 10,
        tankId: 'back',
        gasMix: _air,
        order: 1,
      ),
    ],
  );

  test('a no-stop ascent bills each cylinder for its own stretch', () {
    final plan = noStopPlan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    expect(outcome.stops, isEmpty);

    final ascent = outcome.schedule
        .where((row) => row.kind == PlanScheduleRowKind.ascent)
        .toList();
    expect(ascent, hasLength(2), reason: 'splits at the EAN50 switch depth');
    expect(ascent.last.tankId, 'deco');

    final switchDepth = ascent.first.depthMeters;
    final pressure = PlanEngine.environmentFor(
      plan,
    ).pressureAtDepth(switchDepth / 2);
    final deco = outcome.tankUsages.singleWhere((t) => t.tankId == 'deco');

    expect(
      deco.litersUsed,
      closeTo(sacDeco * (ascent.last.durationSeconds / 60) * pressure, 1e-9),
    );
  });
}
