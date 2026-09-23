import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_line_builders.dart'
    show SeriesGetsLeadIn, WithFlatSurfaceLeadIn;

/// Build vertical markers for gas switch events on the profile.
List<LineChartBarData> buildGasSwitchMarkers(
  UnitFormatter units,
  List<GasSwitchWithTank>? gasSwitches,
  Map<String, bool> showTankPressure,
  double Function(int timestamp) findDepthAtTimestamp,
) {
  if (gasSwitches == null || gasSwitches.isEmpty) {
    return [];
  }

  // A cylinder unchecked in the options dialog hides its switch markers,
  // the same way an unchecked tank hides its pressure trace.
  final visibleSwitches = gasSwitches.where(
    (gs) => showTankPressure[gs.gasSwitch.tankId] ?? true,
  );

  return visibleSwitches.map((gs) {
    final color = GasColors.forMixFraction(gs.o2Fraction, gs.heFraction);

    // Find the depth at this timestamp from profile
    final depth = gs.depth ?? findDepthAtTimestamp(gs.timestamp);

    return LineChartBarData(
      spots: [FlSpot(gs.timestamp.toDouble(), -units.convertDepth(depth))],
      isCurved: false,
      color: Colors.transparent,
      barWidth: 0,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          return FlDotCirclePainter(
            radius: 6,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
    );
  }).toList();
}

/// Build multiple pressure lines for multi-tank visualization
List<LineChartBarData> buildMultiTankPressureLines(
  MetricBand band, {
  required bool hasMultiTankPressure,
  required Map<String, List<TankPressurePoint>>? tankPressures,
  required Map<String, bool> showTankPressure,
  required Set<String>? estimatedTankIds,
  required List<DiveProfilePoint> profile,
  required List<String> Function(Iterable<String> tankIds) sortedTankIds,
  required Map<String, String?> Function() tankComputerIds,
  required bool Function(String? computerId) isComputerVisible,
  required DiveTank? Function(String tankId) getTankById,
  required Color Function(int index) getTankColor,
  required List<int>? Function(int index) getTankDashPattern,
  required WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  required SeriesGetsLeadIn seriesGetsLeadIn,
}) {
  if (!hasMultiTankPressure) return [];

  final tanks = tankPressures!;
  final lines = <LineChartBarData>[];

  // Global min/max pressure across all tanks, for consistent scaling.
  final range = tankPressureRange(tanks);
  if (range == null) return [];
  final globalMinPressure = range.min;
  final globalMaxPressure = range.max;

  // Add some padding to the pressure range
  final pressureRange = globalMaxPressure - globalMinPressure;

  // A zero span means every sample across every tank is identical -- in
  // practice a computer that logged a pressure channel with no transmitter
  // paired (all zeros). There is no pressure information to plot, and mapping
  // a constant value through a zero-width range yields NaN spot coordinates
  // that crash fl_chart's touch/tooltip painter (Offset NaN). Skip it.
  if (pressureRange <= 0) return [];

  final minPressure = globalMinPressure - (pressureRange * 0.05);
  final maxPressure = globalMaxPressure + (pressureRange * 0.05);

  final sortedIds = sortedTankIds(tanks.keys);
  final computerIds = tankComputerIds();

  // Build a line for each visible tank
  for (var i = 0; i < sortedIds.length; i++) {
    final tankId = sortedIds[i];

    // Skip if tank is hidden
    if (showTankPressure[tankId] == false) continue;

    // Skip tanks attributed to a computer that's been toggled off.
    if (!isComputerVisible(computerIds[tankId])) continue;

    final pressurePoints = tanks[tankId]!;
    if (pressurePoints.isEmpty) continue;

    // Get tank for color
    final tank = getTankById(tankId);

    // Use gas color or fallback
    final color = tank != null
        ? GasColors.forGasMix(tank.gasMix)
        : getTankColor(i);
    final dashPattern = getTankDashPattern(i);

    // A tank first breathed mid-dive keeps its own start: the lead-in only
    // bridges a series that begins at the dive's first sample. Built first so
    // the smoothing flag below reflects whether THIS tank got one.
    final tankSpots = pressurePoints
        .map(
          (p) => FlSpot(
            p.timestamp.toDouble(),
            -band.map(p.pressure, minPressure, maxPressure),
          ),
        )
        .toList();
    lines.add(
      LineChartBarData(
        spots: withFlatSurfaceLeadIn(tankSpots),
        // Synthesized estimates are straight (flat-drop-flat); curve
        // smoothing would round their corners. Real AI data stays curved.
        isCurved: !(estimatedTankIds?.contains(tankId) ?? false),
        curveSmoothness: 0.2,
        // The lead-in vertex is a sharp direction change; without this the
        // spline overshoots it and hooks below the curve at the left edge.
        preventCurveOverShooting: seriesGetsLeadIn(tankSpots, profile),
        color: color,
        barWidth: 1,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        dashArray: dashPattern,
      ),
    );
  }

  return lines;
}
