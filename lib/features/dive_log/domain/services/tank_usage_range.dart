import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// A switch this many seconds or less after the dive starts names the
/// starting gas: computers log it at the first sample, not at second zero.
const int startingSwitchGraceSeconds = 60;

/// A stretch of a dive, in seconds, when a cylinder was breathed.
typedef TankUsageWindow = ({int start, int end});

/// The breathing periods of one cylinder, in time order and not overlapping.
extension TankUsageWindows on List<TankUsageWindow> {
  /// Total time breathed.
  int get breathedSeconds => fold(0, (total, w) => total + w.end - w.start);

  /// Time breathed before [timestamp].
  int breathedBefore(int timestamp) => fold(
    0,
    (total, w) => total + math.max(0, math.min(timestamp, w.end) - w.start),
  );

  /// Time breathed from [start] to [end].
  int breathedBetween(int start, int end) =>
      breathedBefore(end) - breathedBefore(start);

  /// Whether a period includes [timestamp], either end of it counting.
  bool covers(int timestamp) =>
      any((w) => timestamp >= w.start && timestamp <= w.end);
}

/// The switches of [gasSwitches] that say when a cylinder of [tanks] was
/// breathed: those naming a current tank (a stale id a re-import left
/// behind says nothing, #110) and, given [before], falling before it (the
/// dive's end).
List<GasSwitchWithTank> knownGasSwitches(
  List<DiveTank> tanks,
  List<GasSwitchWithTank>? gasSwitches, {
  int? before,
}) {
  final tankIds = {for (final t in tanks) t.id};
  return [
    for (final sw in gasSwitches ?? const <GasSwitchWithTank>[])
      if (tankIds.contains(sw.gasSwitch.tankId) &&
          (before == null || sw.gasSwitch.timestamp < before))
        sw,
  ];
}

/// The cylinder breathed at [timestamp]: the one the last switch at or
/// before it names, else the starting gas (see [_startingTank]). Null when
/// there are no cylinders.
DiveTank? activeTankAt({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank>? gasSwitches,
  required int timestamp,
  required int diveStart,
}) {
  if (tanks.isEmpty) return null;
  final sorted = knownGasSwitches(tanks, gasSwitches)
    ..sort((a, b) => a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp));
  final active = sorted.lastWhereOrNull(
    (sw) => sw.gasSwitch.timestamp <= timestamp,
  );
  if (active == null) return _startingTank(tanks, sorted, diveStart);
  return tanks.firstWhere((t) => t.id == active.gasSwitch.tankId);
}

/// The cylinder the dive starts on: the one a switch in its first moments
/// names, since computers log the starting gas at the first sample, else
/// the cylinder a SAC is referenced to (the back gas, else the first).
/// [sortedSwitches] are known switches in time order; [tanks] is non-empty.
DiveTank _startingTank(
  List<DiveTank> tanks,
  List<GasSwitchWithTank> sortedSwitches,
  int diveStart,
) {
  final first = sortedSwitches.firstOrNull;
  if (first != null &&
      first.gasSwitch.timestamp <= diveStart + startingSwitchGraceSeconds) {
    return tanks.firstWhere((t) => t.id == first.gasSwitch.tankId);
  }
  return sacReferenceTankOf(tanks)!;
}

/// The periods, in seconds and time order, when [tank] was breathed: from the
/// dive's gas switches, else the whole dive for the primary gas. A cylinder the
/// diver returned to has one per visit (#3900). Empty when nothing says when
/// the tank was breathed (a stage with no recorded switch).
List<TankUsageWindow> tankUsageWindows({
  required DiveTank tank,
  required List<GasSwitchWithTank>? gasSwitches,
  required int diveStart,
  required int diveEnd,
  required List<DiveTank> tanks,
}) {
  if (diveEnd <= diveStart) return const [];

  // A dive's only cylinder was breathed for all of it, whatever its
  // switches say (issue #3373).
  if (tanks.length == 1) return [(start: diveStart, end: diveEnd)];

  final knownSwitches = knownGasSwitches(tanks, gasSwitches, before: diveEnd);

  if (knownSwitches.isEmpty) {
    // Without switches only the primary gas is known to span the dive: the
    // back gas, or either cylinder of a sidemount pair. A stage's window
    // is unknown, and the whole dive would understate its rate.
    if (tank.role != TankRole.backGas && !sidemountRoles.contains(tank.role)) {
      return const [];
    }
    return [(start: diveStart, end: diveEnd)];
  }

  // A matched pair (sidemount, doubles logged as independents) is breathed
  // in turns on one gas, which a computer records as a single switch onto
  // the first of them, if at all. While some cylinder of the pair has no
  // switch of its own, the pair shares one window (#3373); once each has
  // one, the switches tell them apart.
  final switchedTankIds = {for (final sw in knownSwitches) sw.gasSwitch.tankId};
  final partnerIds = {
    for (final t in tanks)
      if (t.id != tank.id && isMatchedPair(tank, t)) t.id,
  };
  final sharesWindow =
      partnerIds.isNotEmpty &&
      !{tank.id, ...partnerIds}.every(switchedTankIds.contains);
  bool breathedWith(String tankId) =>
      tankId == tank.id || (sharesWindow && partnerIds.contains(tankId));

  final sortedSwitches = [...knownSwitches]
    ..sort((a, b) => a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp));

  // Find all time ranges where this tank was active
  final windows = <TankUsageWindow>[];
  int? periodStart;

  // Check if this tank is the initial tank (before first switch)
  final initialTankId = _startingTank(tanks, sortedSwitches, diveStart).id;
  if (breathedWith(initialTankId)) {
    periodStart = diveStart;
  }

  // Find switches to and from this tank
  for (final sw in sortedSwitches) {
    final timestamp = sw.gasSwitch.timestamp;
    if (breathedWith(sw.gasSwitch.tankId)) {
      // Switched TO this tank
      periodStart ??= timestamp;
    } else if (periodStart != null) {
      // Switched AWAY from this tank, which may yet come back
      if (timestamp > periodStart) {
        windows.add((start: periodStart, end: timestamp));
      }
      periodStart = null;
    }
  }

  // If we found a start but no end, tank was used until dive end
  if (periodStart != null) {
    windows.add((start: periodStart, end: diveEnd));
  }

  return windows;
}
