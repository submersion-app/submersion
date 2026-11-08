import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';
import 'package:submersion/features/insights/domain/role_consumption_trend.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

TrendDataPoint _point(int day, double value) => TrendDataPoint(
  date: DateTime.utc(2026, 1, day),
  value: value,
  diveId: 'd$day',
);

void main() {
  final trend = RoleConsumptionTrend(
    rmv: {
      ConsumptionRoleGroup.bottomGas: [_point(1, 12), _point(2, 18)],
      ConsumptionRoleGroup.stage: [_point(2, 20)],
    },
    leftOutDives: 2,
  );

  test('average is the mean of the per-dive values', () {
    expect(
      trend.average(GasConsumptionLane.rmv, ConsumptionRoleGroup.bottomGas),
      15,
    );
  });

  test('a group with no points has no average', () {
    expect(
      trend.average(GasConsumptionLane.rmv, ConsumptionRoleGroup.deco),
      isNull,
    );
    expect(
      trend.average(GasConsumptionLane.sac, ConsumptionRoleGroup.bottomGas),
      isNull,
    );
  });

  test('forLane and isEmptyFor follow the lane', () {
    expect(trend.forLane(GasConsumptionLane.rmv).keys, [
      ConsumptionRoleGroup.bottomGas,
      ConsumptionRoleGroup.stage,
    ]);
    expect(trend.forLane(GasConsumptionLane.sac), isEmpty);
    expect(trend.isEmptyFor(GasConsumptionLane.rmv), isFalse);
    expect(trend.isEmptyFor(GasConsumptionLane.sac), isTrue);
  });

  test('the empty trend has nothing in either lane', () {
    const empty = RoleConsumptionTrend();
    expect(empty.isEmptyFor(GasConsumptionLane.rmv), isTrue);
    expect(empty.isEmptyFor(GasConsumptionLane.sac), isTrue);
    expect(empty.leftOutDives, 0);
  });
}
