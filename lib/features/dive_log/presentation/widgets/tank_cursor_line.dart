import 'dart:math' as math;

import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';

/// A tank's pressure line as the profile chart draws it, read at the
/// profile cursor for its figure on the Cylinders card (issue #4291).
///
/// Built once per load of the lines; only [pressureAt] runs on each hover
/// frame.
class TankCursorLine {
  TankCursorLine._(this._points, {required this.peak, required this.estimated});

  final List<TankPressurePoint> _points;

  /// The highest pressure on the line, so the figure can keep room for the
  /// widest label the cursor gives it.
  final double peak;

  /// The line is the straight-line estimate from the tank's start and end
  /// pressures, not a transmitter's readings.
  final bool estimated;

  /// Each of [tanks]' lines from [chartSeries], the very lines the profile
  /// chart draws: the transmitter's readings, else the linear estimate
  /// (flat, a straight drop while breathed, flat). A tank the chart draws
  /// no line for (no pressures at all, a gauge dive, or estimates switched
  /// off) has none here, so its figure shows no cursor either. Nor does any
  /// tank when the chart cannot scale the lines at all, every reading of
  /// every tank being the same (see [tankPressureScale]). A series still
  /// keyed by an old tank id is matched as everywhere else (see
  /// [resolveTankPressureSeries]).
  static Map<String, TankCursorLine> forTanks(
    List<DiveTank> tanks,
    EstimatedTankPressures? chartSeries,
  ) {
    if (chartSeries == null) return const {};
    if (tankPressureScale(chartSeries.pressures) == null) return const {};
    return {
      for (final MapEntry(key: tankId, value: points)
          in resolveTankPressureSeries(tanks, chartSeries.pressures).entries)
        if (points.isNotEmpty)
          tankId: TankCursorLine._(
            points,
            peak: points.fold(0.0, (peak, p) => math.max(peak, p.pressure)),
            estimated: chartSeries.estimatedTankIds.contains(tankId),
          ),
    };
  }

  /// The pressure in bar at [seconds] into the dive, read as the chart
  /// reads its own line (see [pressureAtCursor]). Null with no cursor, and
  /// for a negative reading, which is a sensor error, never a pressure.
  double? pressureAt(int? seconds) {
    if (seconds == null) return null;
    final at = pressureAtCursor(_points, seconds);
    return at != null && at >= 0 ? at : null;
  }
}
