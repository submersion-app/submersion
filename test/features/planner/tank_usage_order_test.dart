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

PlanScheduleRow _row(
  String? tankId, {
  double depth = 10,
  String? airBreakTankId,
}) => PlanScheduleRow(
  kind: PlanScheduleRowKind.stop,
  depthMeters: depth,
  durationSeconds: 60,
  runtimeSeconds: 60,
  gasFO2: 0.21,
  gasFHe: 0,
  tankId: tankId,
  gasSwitch: false,
  airBreakTankId: airBreakTankId,
);

PlanScheduleRow _foldedRow(String tankId, List<PlanFoldedTravel> legs) =>
    PlanScheduleRow(
      kind: PlanScheduleRowKind.stop,
      depthMeters: 9,
      durationSeconds: 60,
      runtimeSeconds: 120,
      gasFO2: 0.21,
      gasFHe: 0,
      tankId: tankId,
      foldedTravel: legs,
    );

PlanFoldedTravel _leg(String tankId, {int seconds = 5}) => PlanFoldedTravel(
  fromDepthMeters: 12,
  toDepthMeters: 9,
  seconds: seconds,
  tankId: tankId,
);

void main() {
  test('a cylinder breathed only on folded travel ranks where it is', () {
    final ordered = orderUsagesByFirstUse(
      [_usage('deco'), _usage('mid'), _usage('back')],
      [
        _row('back'),
        _foldedRow('deco', [_leg('back'), _leg('mid'), _leg('deco')]),
      ],
    );
    expect(ordered.map((u) => u.tankId), ['back', 'mid', 'deco']);
  });

  test('a folded stretch of no length is not a use of the cylinder', () {
    final ordered = orderUsagesByFirstUse(
      [_usage('unused'), _usage('deco'), _usage('back')],
      [
        _row('back'),
        _foldedRow('deco', [_leg('unused', seconds: 0)]),
      ],
    );
    expect(ordered.map((u) => u.tankId), ['back', 'deco', 'unused']);
  });

  test('orders usages by the first row that charges each tank', () {
    final ordered = orderUsagesByFirstUse(
      [_usage('deco'), _usage('stage'), _usage('back')],
      [_row('back'), _row('back'), _row('stage'), _row('deco')],
    );
    expect(ordered.map((u) => u.tankId), ['back', 'stage', 'deco']);
  });

  test('a cylinder only ever breathed on an air break takes its place after '
      'the stop gas', () {
    final ordered = orderUsagesByFirstUse(
      [_usage('unused'), _usage('break'), _usage('deco'), _usage('back')],
      [_row('back'), _row('deco', airBreakTankId: 'break')],
    );
    expect(ordered.map((u) => u.tankId), ['back', 'deco', 'break', 'unused']);
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
