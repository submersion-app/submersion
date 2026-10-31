import 'dart:math' as math;

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';
import 'package:submersion/features/dive_log/domain/services/range_profile_stats.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

/// Gas consumption over part of a dive: [sac] in bar/min at the surface, in
/// bar of the dive's reference cylinder, and [rmv] in L/min at the surface.
/// Either is null when the data cannot give it.
typedef RangeGasConsumption = ({double? sac, double? rmv});

/// SAC and RMV between [startTimestamp] and [endTimestamp] (seconds from the
/// dive's start), for the profile range panel (#2928).
///
/// The same two lanes as `Dive.sac` and `Dive.rmvFor`, with each cylinder's
/// start and end pressure read from its transmitter series at the range
/// edges instead of the whole dive's. A cylinder without a series adds
/// nothing: its logged start and end pressures say how much it dropped over
/// the dive, not when. The time is what the series of the cylinders a figure
/// counts cover of the range, since nothing says what was breathed outside
/// them. The depth is [profile]'s average over that same time (#3973), so
/// reaching a selection into time without pressure readings leaves the rate
/// alone; with no depth there, there is no figure. SAC follows
/// `referencePressureDrop`; RMV sums every cylinder with a volume under
/// [model]. Neither exists on a rebreather ([isRebreather]), whose cylinders
/// do not drain with the diver's breathing (issue #3673).
RangeGasConsumption rangeGasConsumption({
  required List<DiveTank> tanks,
  required Map<String, List<TankPressurePoint>> tankPressures,
  required int startTimestamp,
  required int endTimestamp,
  required List<DiveProfilePoint> profile,
  required GasModel model,
  bool isRebreather = false,
}) {
  const none = (sac: null, rmv: null);
  if (isRebreather || endTimestamp <= startTimestamp || tanks.isEmpty) {
    return none;
  }

  final series = resolveTankPressureSeries(tanks, tankPressures);
  final pressures = <String, ({double start, double end})>{};
  for (final tank in tanks) {
    final points = series[tank.id];
    if (points == null || points.length < 2) continue;
    final start = pressureAtTime(points, startTimestamp);
    final end = pressureAtTime(points, endTimestamp);
    if (start == null || end == null || start - end <= 0) continue;
    pressures[tank.id] = (start: start, end: end);
  }
  if (pressures.isEmpty) return none;

  // [amount] per minute at the surface, over the time and depth of the
  // cylinders it came from.
  double? surfaceRate(double amount, Iterable<DiveTank> counted) {
    final windows = _coverage(
      [for (final tank in counted) series[tank.id]!],
      startTimestamp,
      endTimestamp,
    );
    final seconds = windows.breathedSeconds;
    final avgDepth = rangeAverageDepth(profile: profile, windows: windows);
    if (seconds <= 0 || avgDepth == null) return null;
    // Ambient pressure in bar, the 1 bar reference gasVolume returns volumes
    // against.
    final ambientBar = avgDepth / 10 + 1;
    return amount / (seconds / 60) / ambientBar;
  }

  final reference = sacReferenceTankOf(tanks)!;
  final drop = referencePressureDrop(
    reference: reference,
    tanks: tanks,
    dropOf: (tank) {
      final p = pressures[tank.id];
      return p == null ? null : p.start - p.end;
    },
  );
  final sac = drop == null
      ? null
      : surfaceRate(drop, [
          for (final tank in tanks)
            if (pressures.containsKey(tank.id) &&
                referenceBarsPerBar(tank, reference, tanks) != null)
              tank,
        ]);

  double gasLiters = 0;
  final measured = <DiveTank>[];
  for (final tank in tanks) {
    final p = pressures[tank.id];
    final volume = consumptionVolume(tank, tanks);
    if (p == null || volume == null) continue;
    double volumeAt(double bar) => gasVolume(
      tankSizeLiters: volume,
      pressureBar: bar,
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
      model: model,
    );
    final liters = volumeAt(p.start) - volumeAt(p.end);
    if (liters > 0) {
      gasLiters += liters;
      measured.add(tank);
    }
  }
  final rmv = gasLiters > 0 ? surfaceRate(gasLiters, measured) : null;

  return (sac: sac, rmv: rmv);
}

/// The stretches of [start] to [end] that [series] read between them, in time
/// order and not overlapping. A pressure that fell has a series overlapping
/// the range, even when the range sits between two of its readings, so a
/// stretch has a length unless all of a series' readings share one timestamp.
List<TankUsageWindow> _coverage(
  Iterable<List<TankPressurePoint>> series,
  int start,
  int end,
) {
  final windows = [
    for (final points in series)
      (
        start: math.max(start, points.map((p) => p.timestamp).reduce(math.min)),
        end: math.min(end, points.map((p) => p.timestamp).reduce(math.max)),
      ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final merged = <TankUsageWindow>[];
  for (final window in windows) {
    final last = merged.lastOrNull;
    if (last != null && window.start <= last.end) {
      merged.last = (start: last.start, end: math.max(last.end, window.end));
    } else {
      merged.add(window);
    }
  }
  return merged;
}
