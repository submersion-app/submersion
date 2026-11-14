import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A named moment on the buoyancy chart: a dot on the line and a labelled
/// dashed rule down to it.
class BuoyancyChartMarker {
  final int seconds;
  final String label;

  /// An optional marker keeps its dot but gives up its label when the label
  /// would run into another one.
  final bool optional;

  const BuoyancyChartMarker({
    required this.seconds,
    required this.label,
    this.optional = false,
  });
}

/// Net-buoyancy-versus-time line chart. Buoyant (positive) fill above the
/// zero line, heavy (negative) fill below it.
///
/// It can follow the dive profile's cursor both ways (issue #4423):
/// [cursorSeconds] draws a marker at that moment, and [onCursorSeconds]
/// reports the touched or hovered sample's time, then null when the touch
/// lifts or the mouse leaves. With no cursor the line rests on [restSeconds].
///
/// The chart shows no tooltip of its own: whoever hosts it reads the cursor
/// and says what was happening at that moment.
class BuoyancyChart extends StatelessWidget {
  final BuoyancyTwinResult result;
  final UnitFormatter units;
  final double height;
  final int? cursorSeconds;
  final ValueChanged<int?>? onCursorSeconds;
  final List<BuoyancyChartMarker> markers;
  final int? restSeconds;

  const BuoyancyChart({
    super.key,
    required this.result,
    required this.units,
    this.height = 180,
    this.cursorSeconds,
    this.onCursorSeconds,
    this.markers = const [],
    this.restSeconds,
  });

  // Space fl_chart reserves around the plot (axis name plus tick labels).
  static const double _leftReserved = 60;
  static const double _labelGap = 4;
  static const double _markerLabelSize = 11;

  /// True when [s] can be plotted: both its net buoyancy and the unit-converted
  /// y value are finite. A NaN reaching fl_chart is a known crash source.
  static bool _isPlottable(TwinSample s, UnitFormatter units) =>
      s.netKg.isFinite && units.convertWeight(s.netKg).isFinite;

  /// The samples that survive the finite-value filter, in profile order. Kept
  /// in lockstep with [spotsFor] (both derive from this filter), because
  /// fl_chart reports a touched point by its index into the plotted-spot list.
  /// A cursor must therefore resolve against these filtered samples -- not the
  /// raw `result.samples`, which is longer whenever a non-finite sample was
  /// dropped.
  static List<TwinSample> plottableSamples(
    List<TwinSample> samples,
    UnitFormatter units,
  ) => [
    for (final s in samples)
      if (_isPlottable(s, units)) s,
  ];

  /// Chart points in (minutes, converted-net) space, one per plottable sample.
  static List<FlSpot> spotsFor(List<TwinSample> samples, UnitFormatter units) =>
      [
        for (final s in plottableSamples(samples, units))
          FlSpot(s.timestamp / 60.0, units.convertWeight(s.netKg)),
      ];

  /// The indices of the markers whose labels fit. A label sits to the right of
  /// its rule in the left half of the plot and to the left of it in the right
  /// half. Required markers always keep theirs; an optional one keeps its
  /// label only when it clears every label already kept.
  static Set<int> labelledMarkers({
    required List<double> xPx,
    required List<double> labelWidthPx,
    required List<bool> optional,
    required double plotWidthPx,
    double gapPx = 6,
  }) {
    (double, double) span(int i) => xPx[i] < plotWidthPx / 2
        ? (xPx[i] + _labelGap, xPx[i] + _labelGap + labelWidthPx[i])
        : (xPx[i] - _labelGap - labelWidthPx[i], xPx[i] - _labelGap);

    final kept = <int>{
      for (var i = 0; i < xPx.length; i++)
        if (!optional[i]) i,
    };
    for (var i = 0; i < xPx.length; i++) {
      if (!optional[i]) continue;
      final (start, end) = span(i);
      final clear = kept.every((k) {
        final (kStart, kEnd) = span(k);
        return end + gapPx <= kStart || kEnd + gapPx <= start;
      });
      if (clear) kept.add(i);
    }
    return kept;
  }

  @override
  Widget build(BuildContext context) {
    if (result.samples.length < 2) return const SizedBox.shrink();
    // `plotted` and `spots` are parallel (both filter through plottableSamples),
    // so a touched spot's index maps back to the correct sample below.
    final plotted = plottableSamples(result.samples, units);
    final spots = spotsFor(result.samples, units);
    if (spots.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final buoyant = theme.colorScheme.primary;
    final heavy = theme.colorScheme.error;
    final markerStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: _markerLabelSize,
    );

    // Taken from every spot, not the first and last, so the axis does not
    // depend on the samples arriving in time order.
    final xs = [for (final s in spots) s.x];
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    // Each marker snaps to the plotted spot nearest its moment, so its dot
    // lands on the line even when that exact sample was not plottable.
    final markerSpots = [for (final m in markers) _nearestSpot(spots, m)];
    final markerXs = {for (final s in markerSpots) s.x};
    final lineIndex = cursorSeconds ?? restSeconds;

    // Labels sit above the line, so make room for them over its highest point.
    double? maxY;
    if (markers.isNotEmpty) {
      final ys = [for (final s in spots) s.y];
      final top = math.max(ys.reduce(math.max), 0.0);
      final bottom = math.min(ys.reduce(math.min), 0.0);
      maxY = top + math.max(top - bottom, 1.0) * 0.15;
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelled = _labelled(
            context,
            constraints.maxWidth - _leftReserved,
            markerSpots,
            minX,
            maxX,
            markerStyle,
          );
          return LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              maxY: maxY,
              lineTouchData: LineTouchData(
                touchCallback: onCursorSeconds == null
                    ? null
                    : (event, response) {
                        final spot = response?.lineBarSpots?.firstOrNull;
                        onCursorSeconds!(
                          event.isInterestedForInteractions && spot != null
                              ? plotted[spot.spotIndex].timestamp
                              : null,
                        );
                      },
                // No tooltip: the host shows the moment under the cursor.
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) =>
                      List<LineTooltipItem?>.filled(touched.length, null),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameSize: 20,
                  axisNameWidget: Text(
                    '${context.l10n.buoyancy_chartNet} (${units.weightSymbol})',
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameSize: 20,
                  axisNameWidget: Text(
                    context.l10n.buoyancy_chartMinutes,
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        value.toStringAsFixed(0),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                  strokeWidth: 1,
                ),
              ),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  for (var i = 0; i < markers.length; i++)
                    VerticalLine(
                      x: markerSpots[i].x,
                      color: theme.colorScheme.outlineVariant,
                      strokeWidth: 1,
                      dashArray: [2, 4],
                      label: VerticalLineLabel(
                        show: labelled.contains(i),
                        alignment: _labelOnRight(markerSpots[i].x, minX, maxX)
                            ? Alignment.topRight
                            : Alignment.topLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: _labelGap,
                        ),
                        style: markerStyle,
                        labelResolver: (_) => markers[i].label,
                      ),
                    ),
                  // The dive profile's cursor, in a neutral colour: the buoyant
                  // line and fill are the primary colour, which would hide it.
                  if (lineIndex != null)
                    VerticalLine(
                      // Held inside the plot: a cursor on a moment the model
                      // has no sample for rests on the nearest edge, as the
                      // host's readout does.
                      x: (lineIndex / 60.0).clamp(minX, maxX),
                      color: theme.colorScheme.onSurfaceVariant,
                      strokeWidth: 1.5,
                    ),
                ],
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: theme.colorScheme.outline,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: buoyant,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: markers.isNotEmpty,
                    checkToShowDot: (spot, bar) => markerXs.contains(spot.x),
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 3.5,
                          color: buoyant,
                          strokeWidth: 1.5,
                          strokeColor: theme.colorScheme.surface,
                        ),
                  ),
                  // belowBarData with cutOffY 0 tints the buoyant (positive)
                  // region; aboveBarData tints the heavy (negative) region.
                  belowBarData: BarAreaData(
                    show: true,
                    applyCutOffY: true,
                    cutOffY: 0,
                    color: buoyant.withValues(alpha: 0.12),
                  ),
                  aboveBarData: BarAreaData(
                    show: true,
                    applyCutOffY: true,
                    cutOffY: 0,
                    color: heavy.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static FlSpot _nearestSpot(List<FlSpot> spots, BuoyancyChartMarker marker) {
    final x = marker.seconds / 60.0;
    return spots.reduce((a, b) => (b.x - x).abs() < (a.x - x).abs() ? b : a);
  }

  static bool _labelOnRight(double x, double minX, double maxX) =>
      x - minX < (maxX - minX) / 2;

  Set<int> _labelled(
    BuildContext context,
    double plotWidth,
    List<FlSpot> markerSpots,
    double minX,
    double maxX,
    TextStyle style,
  ) {
    if (markers.isEmpty) return const {};
    final spanX = maxX - minX;
    if (plotWidth <= 0 || spanX <= 0) {
      return {for (var i = 0; i < markers.length; i++) i};
    }
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return labelledMarkers(
      xPx: [for (final s in markerSpots) (s.x - minX) / spanX * plotWidth],
      labelWidthPx: [
        for (final m in markers)
          () {
            final painter = TextPainter(
              text: TextSpan(text: m.label, style: style),
              textDirection: direction,
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }(),
      ],
      optional: [for (final m in markers) m.optional],
      plotWidthPx: plotWidth,
    );
  }
}
