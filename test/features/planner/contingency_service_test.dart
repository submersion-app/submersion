import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _backGas = GasMix(o2: 18, he: 45);
const _backTank = DiveTank(
  id: 'back',
  volume: 24,
  startPressure: 232,
  gasMix: _backGas,
);
const _ean50 = DiveTank(
  id: 'ean50',
  volume: 11.1,
  startPressure: 207,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.oc,
  List<DiveTank> tanks = const [_backTank, _ean50],
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Contingency test',
    mode: mode,
    gfLow: 50,
    gfHigh: 80,
    deviationDepthDelta: 5.0,
    deviationTimeMinutes: 5,
    tanks: tanks,
    segments: [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 60.0,
        tankId: 'back',
        gasMix: _backGas,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 60.0,
        durationMinutes: 25,
        tankId: 'back',
        gasMix: _backGas,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  const service = ContingencyService();
  const engine = PlanEngine();

  test('deviations produce deeper, longer, and combined variants', () {
    final base = engine.compute(_plan());
    final deviations = service.deviations(_plan());

    expect(deviations.map((d) => d.key), ['deeper', 'longer', 'both']);
    final deeper = deviations[0];
    final longer = deviations[1];
    final both = deviations[2];

    expect(deeper.outcome.maxDepth, closeTo(65.0, 0.01));
    expect(deeper.outcome.totalDecoSeconds, greaterThan(base.totalDecoSeconds));
    expect(longer.outcome.maxDepth, closeTo(60.0, 0.01));
    expect(longer.outcome.totalDecoSeconds, greaterThan(base.totalDecoSeconds));
    expect(
      both.outcome.totalDecoSeconds,
      greaterThan(deeper.outcome.totalDecoSeconds),
    );
    expect(
      both.outcome.totalDecoSeconds,
      greaterThan(longer.outcome.totalDecoSeconds),
    );
  });

  test('lost EAN50 lengthens deco and removes the gas from the stops', () {
    final base = engine.compute(_plan());
    final lost = service.lostGas(_plan());

    expect(lost, hasLength(1));
    expect(lost.single.tank.id, 'ean50');
    final outcome = lost.single.outcome;
    expect(outcome.totalDecoSeconds, greaterThan(base.totalDecoSeconds));
    for (final stop in outcome.stops.where((s) => s.depthMeters <= 22.0)) {
      expect(stop.gasFO2, isNot(closeTo(0.50, 0.01)));
    }
  });

  test('CCR plans yield no lost-gas outcomes', () {
    expect(service.lostGas(_plan(mode: domain.PlanMode.ccr)), isEmpty);
  });

  test('no segments yields no deviations', () {
    final empty = domain.DivePlan(
      id: 'p',
      name: 'empty',
      gfLow: 50,
      gfHigh: 80,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );
    expect(service.deviations(empty), isEmpty);
  });
}
