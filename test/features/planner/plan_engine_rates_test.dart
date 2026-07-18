import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

List<PlanSegment> _segments() => [
  PlanSegment.descent(
    id: 'seg-1',
    targetDepth: 45,
    tankId: 'tank-1',
    gasMix: _air,
    order: 0,
  ),
  PlanSegment.bottom(
    id: 'seg-2',
    depth: 45,
    durationMinutes: 20,
    tankId: 'tank-1',
    gasMix: _air,
    order: 1,
  ),
];

domain.DivePlan _plan({required double ascentRate}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Rates test',
  gfLow: 30,
  gfHigh: 70,
  ascentRate: ascentRate,
  segments: _segments(),
  tanks: const [_airTank],
  createdAt: DateTime(2026, 7, 17),
  updatedAt: DateTime(2026, 7, 17),
);

void main() {
  test('a slower ascent rate lengthens the computed time to surface', () {
    const engine = PlanEngine();
    final fast = engine.compute(_plan(ascentRate: 9));
    final slow = engine.compute(_plan(ascentRate: 6));
    expect(slow.ttsAtBottom, greaterThan(fast.ttsAtBottom));
  });
}
