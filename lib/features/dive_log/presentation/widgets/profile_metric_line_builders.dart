import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show ceilingFillAlpha;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_bands.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// Signature of `_DiveProfileChartState._decimatedCurveIndices`, decimated
/// sample indices for a numeric curve.
typedef DecimatedCurveIndices = List<int> Function(List<num> values);

/// Signature of `_DiveProfileChartState._decimatedNullableCurveIndices`.
typedef DecimatedNullableCurveIndices = List<int> Function(List<int?> curve);

/// Signature of `_DiveProfileChartState._withFlatSurfaceLeadIn`.
typedef WithFlatSurfaceLeadIn = List<FlSpot> Function(List<FlSpot> spots);

/// Signature of `_DiveProfileChartState._withSurfaceLeadIn`.
typedef WithSurfaceLeadIn =
    List<FlSpot> Function(List<FlSpot> spots, double surfaceY);

/// Signature of `_DiveProfileChartState._surfaceValueOf`.
typedef SurfaceValueOf = double Function(double valueAtFirstSample);

/// Signature of `_DiveProfileChartState._seriesGetsLeadIn`.
typedef SeriesGetsLeadIn =
    bool Function(List<FlSpot> spots, List<DiveProfilePoint> owner);

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

  // Calculate global min/max pressure across all tanks for consistent scaling
  double? globalMinPressure;
  double? globalMaxPressure;

  for (final pressurePoints in tanks.values) {
    for (final point in pressurePoints) {
      if (globalMinPressure == null || point.pressure < globalMinPressure) {
        globalMinPressure = point.pressure;
      }
      if (globalMaxPressure == null || point.pressure > globalMaxPressure) {
        globalMaxPressure = point.pressure;
      }
    }
  }

  if (globalMinPressure == null || globalMaxPressure == null) return [];

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

LineChartBarData buildHeartRateLine(
  Color color,
  MetricBand band,
  double minHR,
  double maxHR,
  List<DiveProfilePoint> profile,
) {
  return LineChartBarData(
    spots: profile
        .where((p) => p.heartRate != null)
        .map(
          (p) => FlSpot(
            p.timestamp.toDouble(),
            -band.map(p.heartRate!.toDouble(), minHR, maxHR),
          ),
        )
        .toList(),
    isCurved: true,
    curveSmoothness: 0.2,
    color: color,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal. Heart
    // rate has no overlay counterpart, so nothing relies on this dash.
  );
}

/// Build SAC (Surface Air Consumption) curve line
LineChartBarData buildSacLine(
  MetricBand band,
  double minSac,
  double maxSac,
  List<double> sacCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const sacColor = ProfileMetricColors.sac;

  // Build spots for each profile point that has SAC data
  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(sacCurve)) {
    final sac = sacCurve[i];
    if (sac > 0) {
      spots.add(
        FlSpot(profile[i].timestamp.toDouble(), -band.map(sac, minSac, maxSac)),
      );
    }
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.3,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: sacColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal. SAC has
    // no overlay counterpart, so nothing relies on this dash.
  );
}

/// Build the separate ascent-rate magnitude line: signed rate (m/min) mapped
/// into the depth plot area so ascents rise above and descents dip below the
/// vertical mid-plot. Self-scaled via the ascent-rate axis range so the line
/// and the optional right-axis labels share one scale.
LineChartBarData buildAscentRateLine(
  MetricBand band,
  List<AscentRatePoint> ascentRates,
  List<DiveProfilePoint> profile,
  ({double min, double max}) range,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  final spots = <FlSpot>[];
  for (var i = 0; i < profile.length && i < ascentRates.length; i++) {
    // Normalisation is unit-invariant, so map the stored m/min value
    // directly; the right axis converts to the user's unit at label time.
    spots.add(
      FlSpot(
        profile[i].timestamp.toDouble(),
        -band.map(ascentRates[i].rateMetersPerMin, range.min, range.max),
      ),
    );
  }
  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: Colors.lime,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

double calculateDepthInterval(double maxDepth) {
  if (maxDepth <= 10) return 2;
  if (maxDepth <= 20) return 5;
  if (maxDepth <= 50) return 10;
  return 20;
}

double calculateTimeInterval(double maxTime) {
  final minutes = maxTime / 60;
  if (minutes <= 10) return 60; // 1 min intervals
  if (minutes <= 30) return 300; // 5 min intervals
  if (minutes <= 60) return 600; // 10 min intervals
  return 900; // 15 min intervals
}

/// Build the ceiling line (decompression ceiling)
LineChartBarData buildCeilingLine(
  UnitFormatter units,
  List<double> ceilingCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  // Purple 700 - distinct from the red deco-stop band it sits beside.
  const ceilingColor = ProfileMetricColors.ceiling;

  // Build spots only where ceiling > 0, breaking the curve wherever the
  // obligation clears. fl_chart splits a bar on null spots and gives each
  // section its own fill, so without the break a profile that re-enters deco
  // would join its two runs and shade the ceiling-free stretch between them.
  // The break is deferred to the next real spot so no null leads or trails.
  final spots = <FlSpot>[];
  var pendingBreak = false;
  for (final i in decimatedCurveIndices(ceilingCurve)) {
    final ceiling = ceilingCurve[i];
    if (ceiling <= 0) {
      if (spots.isNotEmpty) pendingBreak = true;
      continue;
    }
    if (pendingBreak) {
      spots.add(FlSpot.nullSpot);
      pendingBreak = false;
    }
    spots.add(
      FlSpot(
        profile[i].timestamp.toDouble(),
        -units.convertDepth(ceiling), // Convert and negate for inverted axis
      ),
    );
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: ceilingColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal. The
    // overlaid source's own ceiling line keeps its own, independent dash
    // (see _buildOverlayLines), so this is unaffected either way.
    // The shaded region runs from the ceiling UP to the surface, so it is an
    // aboveBarData. Negated depths put the surface (y = 0) above the ceiling
    // (y = -4.2), and a below-bar fill cannot express that: fl_chart's
    // painter draws the below-bar area and then erases the entire above-line
    // region to clean up the cut-off overdraw, wiping exactly this fill. Same
    // defect, and same fix, as the deco stop band in deco_stop_band.dart.
    aboveBarData: BarAreaData(
      show: true,
      color: ceilingColor.withValues(alpha: ceilingFillAlpha),
      cutOffY: 0, // Fill to surface
      applyCutOffY: true,
    ),
  );
}

/// Build NDL (No Decompression Limit) line
/// NDL values are in seconds; shows time remaining before deco obligation
LineChartBarData buildNdlLine(
  MetricBand band,
  List<int> ndlCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
) {
  const ndlColor = ProfileMetricColors.ndl;

  // Map NDL to chart: max NDL (~60 min) at top, 0 at bottom
  final maxNdlSeconds = ProfileMetricBands.ndl.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(ndlCurve)) {
    // Draw NDL only while there is actually no-deco time left. Once it is
    // spent (zero, or negative in deco) the line simply ends -- a flat line
    // pinned at zero through the deco phase carries no information. A null
    // spot breaks the series so it does not bridge straight across the gap.
    if (ndlCurve[i] <= 0) {
      if (spots.isNotEmpty && spots.last != FlSpot.nullSpot) {
        spots.add(FlSpot.nullSpot);
      }
      continue;
    }
    // Clamp values > 60 min to the top of the display range.
    final ndl = ndlCurve[i].clamp(0, maxNdlSeconds.toInt()).toDouble();
    final normalized = ndl / maxNdlSeconds;
    final yValue = band.mapNormalized(normalized);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    // Held flat, not forced to maximum: on a repetitive dive the NDL at the
    // surface is already cut short by residual loading, which the first
    // sample reflects and a synthetic maximum would not.
    spots: withFlatSurfaceLeadIn(spots),
    // Straight segments: a spline across the null-spot breaks would reach
    // for the gap and overshoot.
    isCurved: false,
    color: ndlColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: the active line's colour is already unique among metrics, so
    // the dash (kept for the overlay comparison of this same metric, see
    // ProfileMetricBands) would only add visual noise here (issue #2228).
  );
}

/// Build ppO2 (partial pressure of oxygen) line
/// Values typically range from 0.21 (surface air) to 1.6+ (critical)
LineChartBarData buildPpO2Line(
  MetricBand band,
  List<double> ppO2Curve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithSurfaceLeadIn withSurfaceLeadIn,
  SurfaceValueOf surfaceValueOf,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const ppO2Color = ProfileMetricColors.ppO2;

  // Map ppO2 to chart: 0 at top, 2.0 bar at bottom
  final minPpO2 = ProfileMetricBands.ppO2.min;
  final maxPpO2 = ProfileMetricBands.ppO2.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(ppO2Curve)) {
    final ppO2 = ppO2Curve[i].clamp(minPpO2, maxPpO2);
    final yValue = band.map(ppO2, minPpO2, maxPpO2);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    // ppO2 scales with ambient pressure, so its surface value is computed,
    // not held flat: at 1 bar it is simply the oxygen fraction.
    spots: withSurfaceLeadIn(
      spots,
      -band.map(
        surfaceValueOf(ppO2Curve.first).clamp(minPpO2, maxPpO2),
        minPpO2,
        maxPpO2,
      ),
    ),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: ppO2Color,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build ppN2 (partial pressure of nitrogen) line
LineChartBarData buildPpN2Line(
  MetricBand band,
  List<double> ppN2Curve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithSurfaceLeadIn withSurfaceLeadIn,
  SurfaceValueOf surfaceValueOf,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const ppN2Color = ProfileMetricColors.ppN2;

  // Map ppN2 to chart: 0 at top, ~5 bar at bottom (deep dive)
  final minPpN2 = ProfileMetricBands.ppN2.min;
  final maxPpN2 = ProfileMetricBands.ppN2.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(ppN2Curve)) {
    final ppN2 = ppN2Curve[i].clamp(minPpN2, maxPpN2);
    final yValue = band.map(ppN2, minPpN2, maxPpN2);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    // Computed, not held flat: at 1 bar ppN2 is the nitrogen fraction.
    spots: withSurfaceLeadIn(
      spots,
      -band.map(
        surfaceValueOf(ppN2Curve.first).clamp(minPpN2, maxPpN2),
        minPpN2,
        maxPpN2,
      ),
    ),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: ppN2Color,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build ppHe (partial pressure of helium) line for trimix dives
LineChartBarData buildPpHeLine(
  MetricBand band,
  List<double> ppHeCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithSurfaceLeadIn withSurfaceLeadIn,
  SurfaceValueOf surfaceValueOf,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const ppHeColor = ProfileMetricColors.ppHe;

  // Map ppHe to chart: 0 at top, ~3 bar at bottom
  final minPpHe = ProfileMetricBands.ppHe.min;
  final maxPpHe = ProfileMetricBands.ppHe.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(ppHeCurve)) {
    final ppHe = ppHeCurve[i];
    if (ppHe > 0.001) {
      final clamped = ppHe.clamp(minPpHe, maxPpHe);
      final yValue = band.map(clamped, minPpHe, maxPpHe);
      spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
    }
  }

  return LineChartBarData(
    // Computed, not held flat: at 1 bar ppHe is the helium fraction. The
    // ppHe > 0.001 filter above means a non-trimix dive draws nothing at all,
    // and the lead-in is skipped with it.
    spots: withSurfaceLeadIn(
      spots,
      -band.map(
        surfaceValueOf(ppHeCurve.first).clamp(minPpHe, maxPpHe),
        minPpHe,
        maxPpHe,
      ),
    ),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: ppHeColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build MOD (Maximum Operating Depth) line
/// Shows the MOD limit as a horizontal reference line
LineChartBarData buildModLine(
  UnitFormatter units,
  List<double> modCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
) {
  // Amber 600 - distinct from the CNS orange it often overlays.
  const modColor = ProfileMetricColors.mod;

  // MOD is typically constant for a given gas
  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(modCurve)) {
    final mod = modCurve[i];
    if (mod > 0 && mod < 200) {
      spots.add(
        FlSpot(profile[i].timestamp.toDouble(), -units.convertDepth(mod)),
      );
    }
  }

  return LineChartBarData(
    // Held flat, and that is the calculated value: MOD is a property of the
    // gas, not of depth, so it does not change between the surface and the
    // first sample. Only a gas switch moves it.
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: false,
    color: modColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build gas density line (g/L)
/// High density (>5.7 g/L) increases work of breathing
LineChartBarData buildDensityLine(
  MetricBand band,
  List<double> densityCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithSurfaceLeadIn withSurfaceLeadIn,
  SurfaceValueOf surfaceValueOf,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  // Lime 900 (olive) - distinct from the OTU brown.
  const densityColor = ProfileMetricColors.density;

  // Map density to chart: 0 at top, 8 g/L at bottom
  final minDensity = ProfileMetricBands.density.min;
  final maxDensity = ProfileMetricBands.density.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(densityCurve)) {
    final density = densityCurve[i].clamp(minDensity, maxDensity);
    final yValue = band.map(density, minDensity, maxDensity);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    // Gas density scales with ambient pressure, so the surface value is
    // computed rather than held flat.
    spots: withSurfaceLeadIn(
      spots,
      -band.map(
        surfaceValueOf(densityCurve.first).clamp(minDensity, maxDensity),
        minDensity,
        maxDensity,
      ),
    ),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: densityColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build GF% (Gradient Factor percentage) line at current depth
/// Shows how close tissues are to M-value limit
LineChartBarData buildGfLine(
  MetricBand band,
  List<double> gfCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const gfColor = ProfileMetricColors.gf;

  // Map GF% to chart: 0% at top, 120% at bottom
  final minGf = ProfileMetricBands.gf.min;
  final maxGf = ProfileMetricBands.gf.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(gfCurve)) {
    final gf = gfCurve[i].clamp(minGf, maxGf);
    final yValue = band.map(gf, minGf, maxGf);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: gfColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build Surface GF% line (what GF would be if surfaced now)
/// Values >100% indicate deco obligation
LineChartBarData buildSurfaceGfLine(
  MetricBand band,
  List<double> surfaceGfCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const surfaceGfColor = ProfileMetricColors.surfaceGf;

  // Map Surface GF% to chart: 0% at top, 150% at bottom
  final minGf = ProfileMetricBands.surfaceGf.min;
  final maxGf = ProfileMetricBands.surfaceGf.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(surfaceGfCurve)) {
    final gf = surfaceGfCurve[i].clamp(minGf, maxGf);
    final yValue = band.map(gf, minGf, maxGf);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: surfaceGfColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build mean depth line (running average from start)
LineChartBarData buildMeanDepthLine(
  UnitFormatter units,
  List<double> meanDepthCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const meanDepthColor = ProfileMetricColors.meanDepth;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(meanDepthCurve)) {
    spots.add(
      FlSpot(
        profile[i].timestamp.toDouble(),
        -units.convertDepth(meanDepthCurve[i]),
      ),
    );
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: meanDepthColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build TTS (Time To Surface) line
/// Shows total time including deco stops to reach surface
LineChartBarData buildTtsLine(
  MetricBand band,
  List<int> ttsCurve,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const ttsColor = ProfileMetricColors.tts;

  // Map TTS to chart: 0 at top, 60 min at bottom
  final maxTtsSeconds = ProfileMetricBands.tts.fixedMax;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(ttsCurve)) {
    final tts = ttsCurve[i].toDouble().clamp(0, maxTtsSeconds);
    final normalized = tts / maxTtsSeconds;
    final yValue = band.mapNormalized(normalized);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: ttsColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Whether every raw sample strictly between kept indices [from] and [to]
/// is blank, i.e. the line should break rather than bridge them. Decimation
/// also skips present samples, so a gap is only a gap when nothing present
/// was dropped in between.
bool gtrGapBetween(List<int?> curve, int from, int to) {
  if (to - from < 2) return false;
  for (var j = from + 1; j < to; j++) {
    if (curve[j] != null) return false;
  }
  return true;
}

/// Build the gas time remaining line.
///
/// Null samples are where the computer (or the calculation) blanked the
/// value, so the line breaks there instead of dropping to zero. No surface
/// lead-in: GTR is blank on the surface by definition.
LineChartBarData buildGtrLine(
  MetricBand band,
  List<int?> gtrCurve,
  List<DiveProfilePoint> profile,
  DecimatedNullableCurveIndices decimatedNullableCurveIndices,
) {
  // Same 0-60 min band as NDL and TTS so the three read on one scale.
  final maxGtrSeconds = ProfileMetricBands.gtr.fixedMax;

  // Gaps are excluded before decimation (a blank must never be sampled as
  // a zero), then the line is broken wherever consecutive kept samples are
  // not adjacent in the raw curve with only blanks between them.
  final spots = <FlSpot>[];
  var previous = -1;
  for (final i in decimatedNullableCurveIndices(gtrCurve)) {
    if (previous >= 0 && gtrGapBetween(gtrCurve, previous, i)) {
      spots.add(FlSpot.nullSpot);
    }
    final normalized =
        gtrCurve[i]!.toDouble().clamp(0, maxGtrSeconds) / maxGtrSeconds;
    final yValue = band.mapNormalized(normalized);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
    previous = i;
  }

  return LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.2,
    color: ProfileRightAxisMetric.gtr.color!,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build cumulative CNS% line
LineChartBarData buildCnsLine(
  MetricBand band,
  List<double> cnsCurve,
  double cnsMaxScale,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const cnsColor = ProfileMetricColors.cns;

  final minCns = ProfileMetricBands.cns.min;
  final maxCns = cnsMaxScale;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(cnsCurve)) {
    final cns = cnsCurve[i].clamp(minCns, maxCns);
    final yValue = band.map(cns, minCns, maxCns);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: cnsColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}

/// Build cumulative OTU line
LineChartBarData buildOtuLine(
  MetricBand band,
  List<double> otuCurve,
  double otuMaxScale,
  List<DiveProfilePoint> profile,
  DecimatedCurveIndices decimatedCurveIndices,
  WithFlatSurfaceLeadIn withFlatSurfaceLeadIn,
  SeriesGetsLeadIn seriesGetsLeadIn,
) {
  const otuColor = ProfileMetricColors.otu;

  final minOtu = ProfileMetricBands.otu.min;
  final maxOtu = otuMaxScale;

  final spots = <FlSpot>[];
  for (final i in decimatedCurveIndices(otuCurve)) {
    final otu = otuCurve[i].clamp(minOtu, maxOtu);
    final yValue = band.map(otu, minOtu, maxOtu);
    spots.add(FlSpot(profile[i].timestamp.toDouble(), -yValue));
  }

  return LineChartBarData(
    spots: withFlatSurfaceLeadIn(spots),
    isCurved: true,
    curveSmoothness: 0.2,
    // Only while a lead-in is drawn: that vertex is a sharp direction
    // change and the spline would otherwise overshoot it and hook below
    // the curve at the left edge. Dives already starting at t=0 keep
    // their existing smoothing untouched.
    preventCurveOverShooting: seriesGetsLeadIn(spots, profile),
    color: otuColor,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    // Solid: see the comment on buildNdlLine's dashArray removal.
  );
}
