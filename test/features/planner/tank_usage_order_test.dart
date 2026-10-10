import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/tank_usage_order.dart';

PlanTankUsage _usage(String id) => PlanTankUsage(
  tankId: id,
  litersUsed: 0,
  totalLiters: 1000,
  startPressure: 200,
  remainingPressure: 200,
  percentUsed: 0,
  reserveViolation: false,
);

PlanScheduleRow _row(String? tankId, {double depth = 10}) => PlanScheduleRow(
  kind: PlanScheduleRowKind.stop,
  depthMeters: depth,
  durationSeconds: 60,
  runtimeSeconds: 60,
  gasFO2: 0.21,
  gasFHe: 0,
  tankId: tankId,
  gasSwitch: false,
);

void main() {
  test('orders usages by the first row that charges each tank', () {
    final ordered = orderUsagesByFirstUse(
      [_usage('deco'), _usage('stage'), _usage('back')],
      [_row('back'), _row('back'), _row('stage'), _row('deco')],
    );
    expect(ordered.map((u) => u.tankId), ['back', 'stage', 'deco']);
  });

  test('tanks no row charges keep their relative order and follow at the '
      'end', () {
    final ordered = orderUsagesByFirstUse(
      [_usage('unused-b'), _usage('deco'), _usage('unused-a'), _usage('back')],
      [_row('back'), _row('deco')],
    );
    expect(ordered.map((u) => u.tankId), [
      'back',
      'deco',
      'unused-b',
      'unused-a',
    ]);
  });

  test('rows without a tank are ignored; no rows at all leaves the list as '
      'it was', () {
    final usages = [_usage('b'), _usage('a')];
    expect(
      orderUsagesByFirstUse(usages, [_row(null), _row(null)]),
      same(usages),
    );
    expect(orderUsagesByFirstUse(usages, const []), same(usages));
  });
}
