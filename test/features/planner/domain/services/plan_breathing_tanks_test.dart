import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/services/plan_breathing_tanks.dart';

/// A plan holds breathing gas only (issue #4243): a suit inflation bottle
/// that reaches one is stripped on the way in.
void main() {
  const back = DiveTank(id: 'back', gasMix: GasMix(o2: 32));
  const suit = DiveTank(
    id: 'suit',
    gasMix: GasMix(o2: 21),
    role: TankRole.suitInflation,
  );

  PlanSegment segment(String id, String tankId) => PlanSegment(
    id: id,
    targetDepth: 30,
    durationSeconds: 1200,
    tankId: tankId,
    gasMix: const GasMix(o2: 32),
  );

  DivePlanState plan(List<DiveTank> tanks, List<PlanSegment> segments) =>
      DivePlanState(
        id: 'p',
        name: 'Plan',
        tanks: tanks,
        segments: segments,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  test('a plan with no suit bottle is returned as it is', () {
    final p = plan(const [back], [segment('s1', 'back')]);
    expect(identical(withoutSuitInflationCylinders(p), p), isTrue);
  });

  test('strips the bottle and moves its segments to the first tank', () {
    final result = withoutSuitInflationCylinders(
      plan(
        const [suit, back],
        [
          segment('s1', 'suit').copyWith(gasMix: const GasMix(o2: 21)),
          segment('s2', 'back'),
        ],
      ),
    );

    expect(result.tanks, const [back]);
    expect(result.segments.map((s) => s.tankId), ['back', 'back']);
    // A moved segment breathes its new tank's gas, not the bottle's.
    expect(result.segments.first.gasMix, back.gasMix);
  });

  test('a plan with only a bottle keeps it as back gas', () {
    final result = withoutSuitInflationCylinders(
      plan(const [suit], [segment('s1', 'suit')]),
    );

    expect(result.tanks.single.id, 'suit');
    expect(result.tanks.single.role, TankRole.backGas);
    expect(result.segments.single.tankId, 'suit');
  });
}
