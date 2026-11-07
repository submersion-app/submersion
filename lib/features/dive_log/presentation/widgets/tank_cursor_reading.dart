import 'dart:math' as math;

import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';

/// A tank's pressure at the profile cursor, for its figure on the Cylinders
/// card (issue #4291).
class TankCursorReading {
  const TankCursorReading({
    required this.pressure,
    required this.peak,
    required this.estimated,
  });

  /// The pressure in bar at the cursor; null while the cursor is off the
  /// chart (or past the end of the profile it indexes).
  final double? pressure;

  /// The highest pressure on the tank's line, so the figure can keep room
  /// for the widest label the cursor gives it.
  final double peak;

  /// The line is the straight-line estimate from the tank's start and end
  /// pressures, not a transmitter's readings.
  final bool estimated;
}

/// [tank]'s reading at [cursorSeconds] from [chartSeries], the very lines
/// the profile chart draws: the transmitter's readings, else the linear
/// estimate (flat, a straight drop while breathed, flat). Null when the
/// chart draws no line for the tank (no pressures at all, a gauge dive, or
/// estimates switched off), so the figure shows no cursor either.
///
/// A series still keyed by an old tank id is matched as everywhere else
/// (see [resolveTankPressureSeries]). A negative reading is a sensor error,
/// never a pressure, so it reads as no pressure at the cursor.
TankCursorReading? tankCursorReading({
  required DiveTank tank,
  required List<DiveTank> tanks,
  required EstimatedTankPressures? chartSeries,
  required int? cursorSeconds,
}) {
  if (chartSeries == null) return null;
  final series = resolveTankPressureSeries(
    tanks,
    chartSeries.pressures,
  )[tank.id];
  if (series == null || series.isEmpty) return null;
  final at = cursorSeconds == null
      ? null
      : pressureAtTime(series, cursorSeconds);
  return TankCursorReading(
    pressure: at != null && at >= 0 ? at : null,
    peak: series.fold(0.0, (peak, p) => math.max(peak, p.pressure)),
    estimated: chartSeries.estimatedTankIds.contains(tank.id),
  );
}
