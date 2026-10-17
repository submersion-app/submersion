import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// A switch this many seconds or less after the dive starts names the
/// starting gas: computers log it at the first sample, not at second zero.
const int startingSwitchGraceSeconds = 60;

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

/// The time window, in seconds, when [tank] was breathed: from the dive's
/// gas switches, else the whole dive for the primary gas. Null when nothing
/// says when the tank was breathed (a stage with no recorded switch).
({int start, int end})? tankUsageRange({
  required DiveTank tank,
  required List<GasSwitchWithTank>? gasSwitches,
  required int diveStart,
  required int diveEnd,
  required List<DiveTank> tanks,
}) {
  if (diveEnd <= diveStart) return null;

  // A dive's only cylinder was breathed for all of it, whatever its
  // switches say (issue #3373).
  if (tanks.length == 1) return (start: diveStart, end: diveEnd);

  final knownSwitches = knownGasSwitches(tanks, gasSwitches, before: diveEnd);

  if (knownSwitches.isEmpty) {
    // Without switches only the primary gas is known to span the dive: the
    // back gas, or either cylinder of a sidemount pair. A stage's window
    // is unknown, and the whole dive would understate its rate.
    if (tank.role != TankRole.backGas && !sidemountRoles.contains(tank.role)) {
      return null;
    }
    return (start: diveStart, end: diveEnd);
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
  int? rangeStart;
  int totalEnd = diveEnd;

  // Check if this tank is the initial tank (before first switch)
  final initialTankId = _startingTank(tanks, sortedSwitches, diveStart).id;
  if (breathedWith(initialTankId)) {
    rangeStart = diveStart;
  }

  // Find switches to and from this tank
  for (int i = 0; i < sortedSwitches.length; i++) {
    final sw = sortedSwitches[i];
    if (breathedWith(sw.gasSwitch.tankId)) {
      // Switched TO this tank
      rangeStart ??= sw.gasSwitch.timestamp;
    } else if (rangeStart != null) {
      // Switched AWAY from this tank
      totalEnd = sw.gasSwitch.timestamp;
      break;
    }
  }

  // If we found a start but no end, tank was used until dive end
  if (rangeStart != null) {
    return (start: rangeStart, end: totalEnd);
  }

  return null;
}
