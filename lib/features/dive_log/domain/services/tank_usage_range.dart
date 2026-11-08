import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
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

  /// The parts of these periods from [start] to [end].
  List<TankUsageWindow> within(int start, int end) => [
    for (final w in this)
      if (w.start < end && w.end > start)
        (start: math.max(w.start, start), end: math.min(w.end, end)),
  ];
}

/// [windows] as one breathing time, in time order: overlapping or touching
/// windows merged, zero-length ones dropped. A sidemount pair on a shared
/// window then counts its time once, while two stages breathed one after the
/// other add theirs (issue #771).
List<TankUsageWindow> unionOfWindows(Iterable<TankUsageWindow> windows) {
  final sorted = [
    for (final w in windows)
      if (w.end > w.start) w,
  ]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <TankUsageWindow>[];
  for (final w in sorted) {
    final last = merged.lastOrNull;
    if (last != null && w.start <= last.end) {
      merged[merged.length - 1] = (
        start: last.start,
        end: math.max(last.end, w.end),
      );
    } else {
      merged.add(w);
    }
  }
  return merged;
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
/// there are no cylinders. [onLoop] as for [startingTankOf].
DiveTank? activeTankAt({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank>? gasSwitches,
  required int timestamp,
  required int diveStart,
  bool onLoop = false,
}) {
  if (tanks.isEmpty) return null;
  final sorted = knownGasSwitches(tanks, gasSwitches)
    ..sort((a, b) => a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp));
  final active = sorted.lastWhereOrNull(
    (sw) => sw.gasSwitch.timestamp <= timestamp,
  );
  if (active == null) {
    return _startingTank(tanks, sorted, diveStart, onLoop: onLoop);
  }
  return tanks.firstWhere((t) => t.id == active.gasSwitch.tankId);
}

/// The cylinder the dive starts on: the one a switch in its first moments
/// names, since computers log the starting gas at the first sample, else
/// the cylinder a SAC is referenced to (the back gas, else the first).
/// [sortedSwitches] are known switches in time order; [tanks] is non-empty.
DiveTank _startingTank(
  List<DiveTank> tanks,
  List<GasSwitchWithTank> sortedSwitches,
  int diveStart, {
  bool onLoop = false,
}) => startingTankOf(
  tanks: tanks,
  switches: sortedSwitches.map((s) => s.gasSwitch),
  diveStart: diveStart,
  onLoop: onLoop,
)!;

/// The cylinder the dive starts on, by the [_startingTank] rule, from bare
/// switches in any order: one naming a cylinder not in [tanks] is ignored.
/// Null when there are no cylinders.
///
/// [onLoop] is set for a rebreather dive, which starts on its diluent ahead of
/// the SAC reference: its gas list often leads with a bailout (#4020).
DiveTank? startingTankOf({
  required List<DiveTank> tanks,
  required Iterable<GasSwitch> switches,
  required int diveStart,
  bool onLoop = false,
}) {
  if (tanks.isEmpty) return null;
  final tankIds = {for (final t in tanks) t.id};
  final first = switches
      .where((s) => tankIds.contains(s.tankId))
      .sorted((a, b) => a.timestamp.compareTo(b.timestamp))
      .firstOrNull;
  if (first != null &&
      first.timestamp <= diveStart + startingSwitchGraceSeconds) {
    return tanks.firstWhere((t) => t.id == first.tankId);
  }
  final diluent = onLoop
      ? tanks
            .sortedBy<num>((t) => t.order)
            .firstWhereOrNull((t) => t.role == TankRole.diluent)
      : null;
  return diluent ?? sacReferenceTankOf(tanks)!;
}

/// The periods, in seconds and time order, when [tank] was breathed: from the
/// dive's gas switches, else the whole dive for the primary gas. A cylinder the
/// diver returned to has one per visit (#3900). Empty when nothing says when
/// the tank was breathed (a stage with no recorded switch). [onLoop] as for
/// [startingTankOf].
List<TankUsageWindow> tankUsageWindows({
  required DiveTank tank,
  required List<GasSwitchWithTank>? gasSwitches,
  required int diveStart,
  required int diveEnd,
  required List<DiveTank> tanks,
  bool onLoop = false,
}) {
  if (diveEnd <= diveStart) return const [];

  // A dive's only cylinder was breathed for all of it, whatever its
  // switches say (issue #3373).
  if (tanks.length == 1) return [(start: diveStart, end: diveEnd)];

  final knownSwitches = knownGasSwitches(tanks, gasSwitches, before: diveEnd);

  if (knownSwitches.isEmpty) {
    if (onLoop) {
      final starting = _startingTank(tanks, const [], diveStart, onLoop: true);
      return starting.id == tank.id
          ? [(start: diveStart, end: diveEnd)]
          : const [];
    }
    // Without switches only the primary gas is known to span the dive: the
    // backmount gas, or either cylinder of a sidemount pair. A stage's
    // window is unknown, and the whole dive would understate its rate.
    if (!backmountRoles.contains(tank.role) &&
        !sidemountRoles.contains(tank.role)) {
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
  final initialTankId = _startingTank(
    tanks,
    sortedSwitches,
    diveStart,
    onLoop: onLoop,
  ).id;
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
