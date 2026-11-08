import 'package:collection/collection.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

/// Consumption by cylinder role per dive, for both lanes at once (issue
/// #771): [rmv] in L/min and [sac] in bar/min. A group with no points is
/// absent, and each group's points are in date order. Both lanes come back
/// together so the Gas page's lane toggle needs no new read.
class RoleConsumptionTrend {
  const RoleConsumptionTrend({
    this.rmv = const {},
    this.sac = const {},
    this.leftOutDives = 0,
  });

  final Map<ConsumptionRoleGroup, List<TrendDataPoint>> rmv;
  final Map<ConsumptionRoleGroup, List<TrendDataPoint>> sac;

  /// Dives in scope left out of every group because a stage, deco, pony or
  /// bailout cylinder lost gas with no gas switch saying when.
  final int leftOutDives;

  Map<ConsumptionRoleGroup, List<TrendDataPoint>> forLane(
    GasConsumptionLane lane,
  ) => switch (lane) {
    GasConsumptionLane.rmv => rmv,
    GasConsumptionLane.sac => sac,
  };

  /// The mean of [group]'s per-dive values in [lane], null with no points.
  double? average(GasConsumptionLane lane, ConsumptionRoleGroup group) {
    final points = forLane(lane)[group];
    if (points == null || points.isEmpty) return null;
    return points.map((p) => p.value).average;
  }
}
