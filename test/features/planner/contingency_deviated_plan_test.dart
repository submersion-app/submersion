import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/contingency_service.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({bool withBottom = true}) => domain.DivePlan(
  id: 'dev',
  name: 'Deviated',
  mode: domain.PlanMode.ccr,
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
      id: 'bo',
      volume: 11.1,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.bailout,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: 40,
      ratePerMinute: 18,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
    ),
    if (withBottom)
      PlanSegment.hold(
        id: 'bottom',
        depth: 40,
        durationMinutes: 25,
        tankId: 'dil',
        gasMix: _air,
        order: 1,
      ),
  ],
);

int _totalSeconds(domain.DivePlan plan) =>
    plan.segments.fold(0, (sum, s) => sum + s.durationSeconds);

void main() {
  const service = ContingencyService();

  test('deeper and longer apply as contingencyFor applies them', () {
    final plan = _plan();
    final deviated = service.deviatedPlan(plan, deeper: true, longer: true)!;
    final combined = service.contingencyFor(plan, deeper: true, longer: true)!;

    expect(deviated.maxDepth, combined.plan.maxDepth);
    expect(deviated.maxDepth, greaterThan(plan.maxDepth));
    expect(_totalSeconds(deviated), _totalSeconds(combined.plan));
    expect(_totalSeconds(deviated), greaterThan(_totalSeconds(plan)));
  });

  test('nothing selected is no deviated plan', () {
    expect(service.deviatedPlan(_plan()), isNull);
  });

  test('+time without a bottom is no deviated plan', () {
    expect(
      service.deviatedPlan(_plan(withBottom: false), longer: true),
      isNull,
    );
  });
}
