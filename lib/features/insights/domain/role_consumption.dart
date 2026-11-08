import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/time_weighted_mean.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

/// The lines of the Gas page's consumption by cylinder role card (issue
/// #771), in the chart's series order.
enum ConsumptionRoleGroup { bottomGas, stage, deco, pony, bailout }

/// The group a cylinder of [role] counts in on an open-circuit dive. The
/// primary gas is one group however it is worn: a sidemount pair is breathed
/// in turns on one gas, so a per-side rate would be about half the diver's.
/// Null for the loop roles, which the Rebreather gas use card covers.
ConsumptionRoleGroup? consumptionRoleGroupOf(TankRole role) => switch (role) {
  TankRole.backGas ||
  TankRole.twinSet ||
  TankRole.sidemountLeft ||
  TankRole.sidemountRight => ConsumptionRoleGroup.bottomGas,
  TankRole.stage => ConsumptionRoleGroup.stage,
  TankRole.deco => ConsumptionRoleGroup.deco,
  TankRole.pony => ConsumptionRoleGroup.pony,
  TankRole.bailout => ConsumptionRoleGroup.bailout,
  TankRole.diluent || TankRole.oxygenSupply => null,
};

/// One dive's consumption per role group: [rmv] in L/min and [sac] in bar/min
/// of the group's reference cylinder. A group without a figure is absent.
class DiveRoleConsumption {
  const DiveRoleConsumption({
    this.rmv = const {},
    this.sac = const {},
    this.leftOut = false,
  });

  final Map<ConsumptionRoleGroup, double> rmv;
  final Map<ConsumptionRoleGroup, double> sac;

  /// The dive has no figures because a stage, deco, pony or bailout cylinder
  /// lost gas with nothing saying when it was breathed.
  final bool leftOut;
}

/// The groups whose cylinders are breathed only part of the dive, so their
/// time must come from a gas switch.
const _switchTimedGroups = {
  ConsumptionRoleGroup.stage,
  ConsumptionRoleGroup.deco,
  ConsumptionRoleGroup.pony,
  ConsumptionRoleGroup.bailout,
};

/// Folds [cylinders], the dive detail's own per-cylinder rows for [dive]
/// (`GasAnalysisService.calculateCylinderSac` on the same inputs), into one
/// figure per role group.
///
/// A group's figure is its cylinders' gas over the time they were breathed,
/// depth corrected at the mean depth of that time. With one cylinder it is
/// that cylinder's own rate. A cylinder whose size cannot be measured in a
/// lane leaves that lane with its time. When a stage, deco, pony or bailout
/// cylinder lost gas without a switch saying when, the whole dive is
/// [DiveRoleConsumption.leftOut]: the primary gas window would then span its
/// minutes too. On a CCR dive only bailout gas counts, in the bailout group.
///
/// [counted] picks the cylinders that count, for a dive holding two
/// recordings' copies of one cylinder; all count when it is null.
DiveRoleConsumption roleConsumptionForDive({
  required Dive dive,
  required List<CylinderSac> cylinders,
  required List<DiveProfilePoint> profile,
  Map<String, List<TankPressurePoint>>? tankPressures,
  bool Function(DiveTank tank)? counted,
}) {
  final tanks = {
    for (final tank in dive.tanks)
      if (counted?.call(tank) ?? true) tank.id: tank,
  };
  final rows = [
    for (final row in cylinders)
      if (tanks.containsKey(row.tankId)) row,
  ];

  if (!dive.isCCR && dive.tanks.length > 1) {
    if (_hasUntimedCylinder(dive, tanks.values, rows, tankPressures)) {
      return const DiveRoleConsumption(leftOut: true);
    }
  }

  final groups = <ConsumptionRoleGroup, List<CylinderSac>>{};
  for (final row in rows) {
    if (row.sacRate == null) continue;
    final group = dive.isCCR
        ? ConsumptionRoleGroup.bailout
        : consumptionRoleGroupOf(row.role);
    if (group == null) continue;
    groups.putIfAbsent(group, () => []).add(row);
  }

  final rmv = <ConsumptionRoleGroup, double>{};
  final sac = <ConsumptionRoleGroup, double>{};
  for (final MapEntry(key: group, value: groupRows) in groups.entries) {
    final ordered = groupRows.sortedBy<num>((r) => r.order);
    final rmvFigure = _rmv(dive, ordered, tanks, profile);
    if (rmvFigure != null) rmv[group] = rmvFigure;
    final sacFigure = _sac(dive, ordered, tanks, profile);
    if (sacFigure != null) sac[group] = sacFigure;
  }
  return DiveRoleConsumption(rmv: rmv, sac: sac);
}

/// Whether a counted stage, deco, pony or bailout cylinder lost gas with no
/// switch saying when: no row at all, or one timed by a recorded duration,
/// which says how long but not at what depth.
bool _hasUntimedCylinder(
  Dive dive,
  Iterable<DiveTank> tanks,
  List<CylinderSac> rows,
  Map<String, List<TankPressurePoint>>? tankPressures,
) {
  final series = resolveTankPressureSeries(dive.tanks, tankPressures);
  final rowsById = {for (final row in rows) row.tankId: row};
  for (final tank in tanks) {
    final group = consumptionRoleGroupOf(tank.role);
    if (!_switchTimedGroups.contains(group)) continue;
    final (start, end) = resolvedTankPressures(tank, series[tank.id]);
    final lostGas = start != null && end != null && start > end;
    if (!lostGas) continue;
    final row = rowsById[tank.id];
    if (row == null || row.usageFromRecordedDuration) return true;
  }
  return false;
}

/// Surface litres behind [row]'s rate, or null without a size.
double? _liters(CylinderSac row) {
  final rmv = row.rmv;
  final ambient = row.rateAmbientBar;
  final seconds = row.usageDuration?.inSeconds;
  if (rmv == null || ambient == null || seconds == null) return null;
  return rmv * (seconds / 60) * ambient;
}

/// [row]'s drop in its own bar at the surface, the gas behind its rate.
double? _ownBar(CylinderSac row) {
  final rate = row.sacRate;
  final ambient = row.rateAmbientBar;
  final seconds = row.usageDuration?.inSeconds;
  if (rate == null || ambient == null || seconds == null) return null;
  return rate * (seconds / 60) * ambient;
}

double? _rmv(
  Dive dive,
  List<CylinderSac> rows,
  Map<String, DiveTank> tanks,
  List<DiveProfilePoint> profile,
) {
  final counting = [
    for (final row in rows)
      if (_liters(row) != null) row,
  ];
  if (counting.isEmpty) return null;
  final liters = counting.map((r) => _liters(r)!).sum;
  return _perCorrectedMinute(liters, dive, counting, tanks, profile);
}

/// In bar of the group's first sized cylinder, else its first: another
/// cylinder converts by volume, or counts one to one as the reference's
/// matched partner.
double? _sac(
  Dive dive,
  List<CylinderSac> rows,
  Map<String, DiveTank> tanks,
  List<DiveProfilePoint> profile,
) {
  final reference =
      rows.firstWhereOrNull((r) => r.tankVolume != null) ?? rows.first;
  final referenceVolume = reference.tankVolume;
  var bar = 0.0;
  final counting = <CylinderSac>[];
  for (final row in rows) {
    final liters = _liters(row);
    final ownBar = _ownBar(row);
    if (referenceVolume != null && row.tankVolume != null && liters != null) {
      bar += liters / referenceVolume;
    } else if (ownBar != null &&
        (identical(row, reference) ||
            _matched(tanks[row.tankId], tanks[reference.tankId]))) {
      bar += ownBar;
    } else {
      continue;
    }
    counting.add(row);
  }
  if (counting.isEmpty) return null;
  return _perCorrectedMinute(bar, dive, counting, tanks, profile);
}

bool _matched(DiveTank? a, DiveTank? b) =>
    a != null && b != null && isMatchedPair(a, b);

/// The shortest breathing time a figure stands on. A switch logged a second
/// before the end would otherwise turn a real logged drop into thousands of
/// litres a minute and wreck the chart's scale.
const int _minimumSeconds = 60;

/// [gas] over the depth-corrected minutes [rows] were breathed: the union of
/// their windows, or their recorded durations with a matched pair taking the
/// longer of the two, never more than the dive. Null under a minute.
double? _perCorrectedMinute(
  double gas,
  Dive dive,
  List<CylinderSac> rows,
  Map<String, DiveTank> tanks,
  List<DiveProfilePoint> profile,
) {
  final int seconds;
  final double? ambient;
  if (rows.any((r) => r.usageFromRecordedDuration)) {
    // An unrecorded cylinder alongside carries the whole dive, and one diver
    // cannot breathe for longer than the dive lasted.
    final diveSeconds = rows
        .expand((r) => r.usageWindows)
        .map((w) => w.end)
        .max;
    seconds = math.min(_recordedSeconds(rows, tanks), diveSeconds);
    ambient = rows.first.rateAmbientBar;
  } else {
    final union = unionOfWindows(rows.expand((r) => r.usageWindows));
    seconds = union.breathedSeconds;
    final depth = timeWeightedMeanAcross(
      profile,
      windows: union,
      time: (p) => p.timestamp,
      value: (p) => p.depth,
    );
    ambient = depth != null
        ? dive.environment.pressureAtDepth(depth)
        : rows.first.rateAmbientBar;
  }
  if (seconds < _minimumSeconds || ambient == null || ambient <= 0) {
    return null;
  }
  return gas / (seconds / 60) / ambient;
}

/// Recorded durations added up, a matched pair counting its longer one: the
/// pair was breathed in turns over the same time.
int _recordedSeconds(List<CylinderSac> rows, Map<String, DiveTank> tanks) {
  final clusters = <List<CylinderSac>>[];
  for (final row in rows) {
    final cluster = clusters.firstWhereOrNull(
      (c) => c.any((o) => _matched(tanks[o.tankId], tanks[row.tankId])),
    );
    if (cluster != null) {
      cluster.add(row);
    } else {
      clusters.add([row]);
    }
  }
  return clusters
      .map((c) => c.map((r) => r.usageDuration?.inSeconds ?? 0).max)
      .sum;
}
