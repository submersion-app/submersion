import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Pressure of [series] at [timestamp]: linear between neighbours, clamped
/// to the first/last point; null for an empty series.
double? pressureAtTimestamp(List<TankPressureSample> series, int timestamp) {
  if (series.isEmpty) return null;
  if (timestamp <= series.first.timestamp) return series.first.pressureBar;
  if (timestamp >= series.last.timestamp) return series.last.pressureBar;
  for (var i = 1; i < series.length; i++) {
    final a = series[i - 1];
    final b = series[i];
    if (timestamp <= b.timestamp) {
      final span = b.timestamp - a.timestamp;
      if (span <= 0) return b.pressureBar;
      final f = (timestamp - a.timestamp) / span;
      return a.pressureBar + (b.pressureBar - a.pressureBar) * f;
    }
  }
  return series.last.pressureBar;
}

class ResolvedSac {
  const ResolvedSac(this.litersPerMin, this.source);
  final double litersPerMin;
  final SacSource source;
}

/// Mean ambient pressure over the samples whose timestamp lies in
/// [from, to]; the pressure at the nearest sample when none does.
double _meanAmbient(
  List<int> timestamps,
  List<double> depths,
  DiveEnvironment env,
  int from,
  int to,
) {
  var sum = 0.0;
  var n = 0;
  for (var i = 0; i < timestamps.length; i++) {
    if (timestamps[i] < from || timestamps[i] > to) continue;
    sum += env.pressureAtDepth(depths[i]);
    n++;
  }
  if (n > 0) return sum / n;
  var best = 0;
  for (var i = 1; i < timestamps.length; i++) {
    if ((timestamps[i] - from).abs() < (timestamps[best] - from).abs()) {
      best = i;
    }
  }
  return env.pressureAtDepth(depths.isEmpty ? 0 : depths[best]);
}

/// The span [start, end] over which [tankId] is in force on [schedule].
(int, int)? _usageSpan(TankSchedule schedule, String tankId, int diveEnd) {
  int? start;
  int? end;
  for (var k = 0; k < schedule.intervals.length; k++) {
    final iv = schedule.intervals[k];
    if (iv.tankId != tankId) continue;
    start ??= iv.startTimestamp;
    end = k + 1 < schedule.intervals.length
        ? schedule.intervals[k + 1].startTimestamp
        : diveEnd;
  }
  if (start == null || end == null) return null;
  return (start, end);
}

/// SAC (L/min at surface) at the branch: from the active tank's measured
/// series over a window around T (measured), else that tank's start/end
/// pressure over its usage span (diveAverage), else [fallbackLpm]
/// (logAverage), else [defaultLpm] (defaultValue).
ResolvedSac resolveBranchSac({
  required int branchTimestamp,
  required DiveTank? activeTank,
  required List<TankPressureSample>? activeSeries,
  required TankSchedule schedule,
  required List<int> timestamps,
  required List<double> depths,
  required DiveEnvironment environment,
  double? fallbackLpm,
  required double defaultLpm,
  int windowSeconds = 180,
}) {
  final volume = activeTank?.volume;
  if (activeTank != null && volume != null && volume > 0) {
    final series = activeSeries ?? const [];
    if (series.length >= 2) {
      for (final half in [windowSeconds ~/ 2, 300]) {
        final from = (branchTimestamp - half).clamp(
          series.first.timestamp,
          series.last.timestamp,
        );
        final to = (branchTimestamp + half).clamp(
          series.first.timestamp,
          series.last.timestamp,
        );
        if (to - from < 30) continue;
        final drop =
            pressureAtTimestamp(series, from)! -
            pressureAtTimestamp(series, to)!;
        if (drop <= 0) continue;
        final ambient = _meanAmbient(timestamps, depths, environment, from, to);
        final minutes = (to - from) / 60.0;
        return ResolvedSac(
          drop * volume / minutes / ambient,
          SacSource.measured,
        );
      }
    }
    final start = activeTank.startPressure;
    final end = activeTank.endPressure;
    final span = _usageSpan(
      schedule,
      activeTank.id,
      timestamps.isEmpty ? 0 : timestamps.last,
    );
    if (start != null && end != null && start > end && span != null) {
      final minutes = (span.$2 - span.$1) / 60.0;
      if (minutes > 0) {
        final ambient = _meanAmbient(
          timestamps,
          depths,
          environment,
          span.$1,
          span.$2,
        );
        return ResolvedSac(
          (start - end) * volume / minutes / ambient,
          SacSource.diveAverage,
        );
      }
    }
  }
  if (fallbackLpm != null && fallbackLpm > 0) {
    return ResolvedSac(fallbackLpm, SacSource.logAverage);
  }
  return ResolvedSac(defaultLpm, SacSource.defaultValue);
}

/// Pressure of [tank] at [timestamp]: measured series, else linear between
/// start and end pressure over the tank's usage span (estimated), else the
/// start pressure alone (estimated), else unknown.
TankPressureAtBranch tankPressureAt({
  required DiveTank tank,
  required List<TankPressureSample>? series,
  required TankSchedule schedule,
  required int timestamp,
  required int diveEnd,
}) {
  if (series != null && series.isNotEmpty) {
    return TankPressureAtBranch(
      tankId: tank.id,
      pressureBar: pressureAtTimestamp(series, timestamp),
      source: PressureSource.measured,
    );
  }
  final start = tank.startPressure;
  if (start == null) {
    return TankPressureAtBranch(
      tankId: tank.id,
      pressureBar: null,
      source: PressureSource.unknown,
    );
  }
  final end = tank.endPressure;
  final span = _usageSpan(schedule, tank.id, diveEnd);
  double value = start;
  if (end != null && span != null && span.$2 > span.$1) {
    if (timestamp >= span.$2) {
      value = end;
    } else if (timestamp > span.$1) {
      final f = (timestamp - span.$1) / (span.$2 - span.$1);
      value = start + (end - start) * f;
    }
  }
  return TankPressureAtBranch(
    tankId: tank.id,
    pressureBar: value,
    source: PressureSource.estimated,
  );
}
