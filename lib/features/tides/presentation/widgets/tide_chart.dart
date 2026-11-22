import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/text/join_sentences.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart_colors.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart_layout.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Interactive tide chart showing water height over time.
///
/// Displays:
/// - Continuous tide curve from predictions
/// - High/low tide markers
/// - Current time indicator
/// - Optional "now" marker with current height
///
/// The chart uses the same fl_chart library as [DiveProfileChart] for
/// consistency in visual style and interaction patterns.
///
/// Usage:
/// ```dart
/// TideChart(
///   predictions: tidePredictions,
///   extremes: tideExtremes,
///   now: DateTime.now(),
/// )
/// ```
class TideChart extends StatefulWidget {
  /// Tide predictions to plot as the main curve.
  final List<TidePrediction> predictions;

  /// High/low tide extremes to mark on the chart.
  final List<TideExtreme>? extremes;

  /// Current time for "now" marker. Defaults to DateTime.now().
  final DateTime? now;

  /// Height of the chart widget.
  final double height;

  /// Whether to show the current time marker.
  final bool showNowMarker;

  /// Whether to show extreme markers (high/low tide dots).
  final bool showExtremeMarkers;

  /// Whether to fill the area under the curve.
  final bool showFill;

  /// Callback when a point on the chart is tapped.
  final void Function(TidePrediction? prediction)? onPointSelected;

  /// Time format preference (12h or 24h). Defaults to 24-hour if not specified.
  final TimeFormat timeFormat;

  /// Depth unit preference for height display. Defaults to meters.
  final DepthUnit depthUnit;

  /// Date format preference, which decides whether dates read month-first
  /// ("Jan 15") or day-first ("15 Jan"). Defaults to month-first.
  final DateFormatPreference dateFormat;

  /// Maps a plotted instant to the clock its labels are printed in, such as
  /// a dive site's wall clock. Positions stay in real instants, which never
  /// repeat, so a DST change cannot fold the axis. Identity when null.
  final DateTime Function(DateTime instant)? displayTime;

  /// Size of the text on the chart's marks: the high and low labels and the
  /// "Now" marker.
  static const double markFontSize = 14;

  /// Size of the axis labels.
  static const double axisFontSize = 13;

  /// Widths the left axis takes: its tick labels and, outside them, its
  /// name. Together they are where the plot starts.
  static const double _leftTitlesWidth = 45;
  static const double _leftAxisNameSize = 20;

  const TideChart({
    super.key,
    required this.predictions,
    this.extremes,
    this.now,
    this.height = 200,
    this.showNowMarker = true,
    this.showExtremeMarkers = true,
    this.showFill = true,
    this.onPointSelected,
    this.timeFormat = TimeFormat.twentyFourHour,
    this.depthUnit = DepthUnit.meters,
    this.displayTime,
    this.dateFormat = DateFormatPreference.mmddyyyy,
  });

  @override
  State<TideChart> createState() => _TideChartState();
}

class _TideChartState extends State<TideChart> {
  DateTime _display(DateTime instant) =>
      widget.displayTime?.call(instant) ?? instant;

  @override
  Widget build(BuildContext context) {
    if (widget.predictions.isEmpty) {
      return _buildEmptyState(context);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final axisStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontSize: TideChart.axisFontSize);
    final reference = widget.now ?? DateTime.now();

    // Calculate time range to show one past extreme at the left edge
    // and "now" positioned somewhere after it
    DateTime windowStart;
    DateTime windowEnd;

    if (widget.extremes != null && widget.extremes!.isNotEmpty) {
      // Find extremes before "now", sorted by time descending
      final pastExtremes =
          widget.extremes!.where((e) => e.time.isBefore(reference)).toList()
            ..sort((a, b) => b.time.compareTo(a.time));

      // Find extremes after "now", sorted by time ascending
      final futureExtremes =
          widget.extremes!.where((e) => !e.time.isBefore(reference)).toList()
            ..sort((a, b) => a.time.compareTo(b.time));

      if (pastExtremes.isNotEmpty) {
        // Start a bit before the most recent past extreme for visual padding
        windowStart = pastExtremes.first.time.subtract(
          const Duration(minutes: 30),
        );
      } else {
        // No past extremes, start 6 hours before now
        windowStart = reference.subtract(const Duration(hours: 6));
      }

      if (futureExtremes.length >= 2) {
        // Show through the second future extreme for context
        windowEnd = futureExtremes[1].time.add(const Duration(minutes: 30));
      } else if (futureExtremes.isNotEmpty) {
        // Show through the first future extreme plus some padding
        windowEnd = futureExtremes.first.time.add(const Duration(hours: 6));
      } else {
        // No future extremes, show 12 hours after now
        windowEnd = reference.add(const Duration(hours: 12));
      }
    } else {
      // No extremes available, show 6 hours before and 12 hours after now
      windowStart = reference.subtract(const Duration(hours: 6));
      windowEnd = reference.add(const Duration(hours: 12));
    }

    // Filter predictions to the visible window
    final visiblePredictions = widget.predictions
        .where(
          (p) => !p.time.isBefore(windowStart) && !p.time.isAfter(windowEnd),
        )
        .toList();

    // Use visible predictions for calculations, fall back to all if window is empty
    final effectivePredictions = visiblePredictions.isNotEmpty
        ? visiblePredictions
        : widget.predictions;

    // Use our calculated window boundaries for the chart display,
    // not the prediction times - this ensures "now" is positioned correctly
    final minTime = windowStart;
    final maxTime = windowEnd;

    // Calculate height range with padding
    final heights = effectivePredictions.map((p) => p.heightMeters);
    final minHeight = heights.reduce(math.min);
    final maxHeight = heights.reduce(math.max);
    final heightRange = maxHeight - minHeight;
    final paddedMinHeight = minHeight - (heightRange * 0.1);
    final paddedMaxHeight = maxHeight + (heightRange * 0.1);

    // Convert DateTime to hours from start for X axis
    double timeToX(DateTime time) {
      return time.difference(minTime).inMinutes / 60.0;
    }

    final maxX = timeToX(maxTime);
    final nowX = timeToX(reference);

    // Find current height at reference time (interpolate from nearest predictions)
    double? currentHeight;
    if (effectivePredictions.isNotEmpty) {
      // Find the closest prediction to the reference time
      TidePrediction? closest;
      Duration? closestDiff;
      for (final p in effectivePredictions) {
        final diff = p.time.difference(reference).abs();
        if (closestDiff == null || diff < closestDiff) {
          closest = p;
          closestDiff = diff;
        }
      }
      currentHeight = closest?.heightMeters;
    }

    // Format "Now" label with time and height
    final nowTimeStr = DateFormat(
      widget.timeFormat.pattern,
    ).format(_display(reference));
    final nowHeightStr = currentHeight != null
        ? '${formatFixedForDisplay(DepthUnit.meters.convert(currentHeight, widget.depthUnit), 1)}${widget.depthUnit.symbol}'
        : '';
    // The generated message takes its placeholders in alphabetical order,
    // height first, whatever order the sentence prints them in.
    final nowLabelText = context.l10n.tides_chart_nowLabel(
      nowHeightStr,
      nowTimeStr,
    );

    // Where the plot starts: the left axis's tick labels plus its name.
    const leftAxisWidth =
        TideChart._leftTitlesWidth + TideChart._leftAxisNameSize;

    // Build a textual summary for screen readers
    final extremesSummary =
        widget.extremes != null && widget.extremes!.isNotEmpty
        ? joinSentences(
            widget.extremes!.map((e) {
              final typeLabel = e.type == TideExtremeType.high
                  ? context.l10n.tides_label_high
                  : context.l10n.tides_label_low;
              final displayHeight = DepthUnit.meters.convert(
                e.heightMeters,
                widget.depthUnit,
              );
              final timeStr = DateFormat(
                widget.timeFormat.pattern,
              ).format(_display(e.time));
              return context.l10n.tides_semantic_extremeItem(
                typeLabel,
                timeStr,
                formatFixedForDisplay(displayHeight, 1),
                widget.depthUnit.symbol,
              );
            }).toList(),
            context.l10n.localeName,
          )
        : context.l10n.tides_noExtremesData;

    return Semantics(
      label: context.l10n.tides_semantic_tideChart(extremesSummary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TideChartLegend(
              showExtremeMarkers: widget.showExtremeMarkers,
              showNowMarker: widget.showNowMarker,
            ),
          ),

          // Chart with "Now" label positioned above
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the pixel x-position for the "Now" marker
              final chartDrawingWidth = constraints.maxWidth - leftAxisWidth;
              final nowPixelX =
                  leftAxisWidth + (nowX / maxX) * chartDrawingWidth;
              final nowStyle = TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: TideChart.markFontSize,
                height: 1.2,
                fontWeight: FontWeight.bold,
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // The chart
                  SizedBox(
                    height: widget.height,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: maxX,
                        minY: paddedMinHeight,
                        maxY: paddedMaxHeight,
                        clipData: const FlClipData.all(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: tideChartHeightInterval(
                            heightRange,
                          ),
                          verticalInterval: tideChartTimeInterval(maxX),
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                            strokeWidth: 1,
                          ),
                          getDrawingVerticalLine: (value) => FlLine(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            axisNameSize: TideChart._leftAxisNameSize,
                            axisNameWidget: Text(
                              context.l10n.tides_chart_heightAxis(
                                widget.depthUnit.symbol,
                              ),
                              style: axisStyle,
                            ),
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: TideChart._leftTitlesWidth,
                              interval: tideChartHeightInterval(heightRange),
                              getTitlesWidget: (value, meta) {
                                if (!isOnAxisStep(value, meta)) {
                                  return const SizedBox.shrink();
                                }
                                final displayValue = DepthUnit.meters.convert(
                                  value,
                                  widget.depthUnit,
                                );
                                return Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 4,
                                  ),
                                  child: Text(
                                    formatFixedForDisplay(displayValue, 1),
                                    style: axisStyle,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: tideChartTimeInterval(maxX),
                              getTitlesWidget: (value, meta) {
                                if (!isOnAxisStep(value, meta)) {
                                  return const SizedBox.shrink();
                                }
                                final time = _display(
                                  minTime.add(
                                    Duration(minutes: (value * 60).round()),
                                  ),
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    DateFormat(
                                      widget.timeFormat.pattern,
                                    ).format(time),
                                    style: axisStyle,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              // Tall enough for the Now pill at the
                              // ambient text scale, which it sits in.
                              reservedSize: math.max(
                                24,
                                MediaQuery.textScalerOf(
                                          context,
                                        ).scale(TideChart.markFontSize) *
                                        1.2 +
                                    6,
                              ),
                              interval: tideChartTimeInterval(maxX),
                              getTitlesWidget: (value, meta) {
                                final time = _display(
                                  minTime.add(
                                    Duration(minutes: (value * 60).round()),
                                  ),
                                );
                                // Show day labels at midnight crossings
                                if (time.hour == 0 && time.minute < 30) {
                                  return Text(
                                    DateFormat('EEE').format(time),
                                    style: axisStyle?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        lineBarsData: [
                          // Main tide curve
                          _buildTideCurve(
                            colorScheme,
                            timeToX,
                            paddedMinHeight,
                            paddedMaxHeight,
                            effectivePredictions,
                          ),

                          // Extreme markers
                          if (widget.showExtremeMarkers &&
                              widget.extremes != null)
                            ..._buildExtremeMarkers(timeToX, minTime, maxTime),
                        ],
                        extraLinesData: ExtraLinesData(
                          verticalLines: [
                            // Extreme marker labels (high/low tide)
                            if (widget.showExtremeMarkers &&
                                widget.extremes != null)
                              ..._buildExtremeLabels(
                                context,
                                timeToX,
                                minTime,
                                maxTime,
                                colorScheme,
                                pixelsPerX: maxX > 0
                                    ? chartDrawingWidth / maxX
                                    : 0,
                              ),
                            // Current time marker (line only, label is positioned above chart)
                            if (widget.showNowMarker &&
                                nowX >= 0 &&
                                nowX <= maxX)
                              VerticalLine(
                                x: nowX,
                                color: colorScheme.primary,
                                strokeWidth: 2,
                                dashArray: [4, 4],
                              ),
                          ],
                          horizontalLines: [
                            // Zero line (mean sea level)
                            if (paddedMinHeight < 0 && paddedMaxHeight > 0)
                              HorizontalLine(
                                y: 0,
                                color: colorScheme.outline.withValues(
                                  alpha: 0.5,
                                ),
                                strokeWidth: 1,
                                dashArray: [8, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.only(
                                    right: 4,
                                    bottom: 2,
                                  ),
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: TideChart.axisFontSize,
                                  ),
                                  labelResolver: (line) =>
                                      context.l10n.tides_chart_msl,
                                ),
                              ),
                          ],
                        ),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchCallback: (event, response) {
                            if (widget.onPointSelected != null) {
                              if (response?.lineBarSpots != null &&
                                  response!.lineBarSpots!.isNotEmpty) {
                                final spot = response.lineBarSpots!.first;
                                if (spot.barIndex == 0 &&
                                    spot.spotIndex <
                                        effectivePredictions.length) {
                                  widget.onPointSelected!(
                                    effectivePredictions[spot.spotIndex],
                                  );
                                }
                              } else {
                                widget.onPointSelected!(null);
                              }
                            }
                          },
                          touchTooltipData: LineTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipColor: (spot) =>
                                colorScheme.inverseSurface,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                if (spot.barIndex != 0) return null;
                                if (spot.spotIndex >=
                                    effectivePredictions.length) {
                                  return null;
                                }

                                final prediction =
                                    effectivePredictions[spot.spotIndex];
                                final timeStr = DateFormat(
                                  widget.timeFormat.pattern,
                                ).format(_display(prediction.time));
                                final dateStr = DateFormat(
                                  UnitFormatter.weekdayMonthDayPattern(
                                    widget.dateFormat,
                                  ),
                                ).format(_display(prediction.time));
                                final displayHeight = DepthUnit.meters.convert(
                                  prediction.heightMeters,
                                  widget.depthUnit,
                                );

                                return LineTooltipItem(
                                  '$timeStr\n',
                                  TextStyle(
                                    color: colorScheme.onInverseSurface
                                        .withValues(alpha: 0.7),
                                    fontSize: TideChart.axisFontSize,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${formatFixedForDisplay(displayHeight, 2)}${widget.depthUnit.symbol}\n',
                                      style: TextStyle(
                                        color: colorScheme.onInverseSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    TextSpan(
                                      text: dateStr,
                                      style: TextStyle(
                                        color: colorScheme.onInverseSurface
                                            .withValues(alpha: 0.7),
                                        fontSize: TideChart.axisFontSize,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // "Now" label positioned above the chart
                  if (widget.showNowMarker && nowX >= 0 && nowX <= maxX)
                    Positioned(
                      // Centred on the marker line, but kept inside the
                      // chart when now sits near either end of the window.
                      left: tideChartPillLeft(
                        nowPixelX,
                        tideChartTextWidth(
                              context,
                              nowLabelText.trim(),
                              nowStyle,
                            ) +
                            2 * tideChartNowPillPadding,
                        constraints.maxWidth,
                      ),
                      top: 0, // At the very top of the reserved space
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: tideChartNowPillPadding,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          nowLabelText.trim(),
                          maxLines: 1,
                          softWrap: false,
                          style: nowStyle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.waves,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tides_noDataAvailable,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildTideCurve(
    ColorScheme colorScheme,
    double Function(DateTime) timeToX,
    double minY,
    double maxY,
    List<TidePrediction> predictions,
  ) {
    return LineChartBarData(
      spots: predictions
          .map((p) => FlSpot(timeToX(p.time), p.heightMeters))
          .toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: colorScheme.primary,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: widget.showFill
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.3),
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
            )
          : BarAreaData(show: false),
    );
  }

  List<LineChartBarData> _buildExtremeMarkers(
    double Function(DateTime) timeToX,
    DateTime minTime,
    DateTime maxTime,
  ) {
    if (widget.extremes == null || widget.extremes!.isEmpty) {
      return [];
    }
    final marks = TideChartColors.of(context);
    // The ring punches the dot out of the curve, so it takes the colour
    // behind the chart (usually its card): a fixed white glared on a dark
    // chart.
    final ring = backdropColorOf(context);

    // Filter extremes within visible range
    final visibleExtremes = widget.extremes!
        .where((e) => !e.time.isBefore(minTime) && !e.time.isAfter(maxTime))
        .toList();

    return visibleExtremes.map((extreme) {
      final isHigh = extreme.type == TideExtremeType.high;
      final color = isHigh ? marks.high : marks.low;

      return LineChartBarData(
        spots: [FlSpot(timeToX(extreme.time), extreme.heightMeters)],
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
              strokeColor: ring,
            );
          },
        ),
      );
    }).toList();
  }

  /// Build vertical lines with labels for extreme markers (high/low tide).
  ///
  /// A label is centred on its extreme, unless that would carry it past an
  /// edge of the plot (the window opens and closes 30 minutes from an
  /// extreme), in which case it is drawn on the inner side of its line.
  /// [pixelsPerX] converts the chart's hour units to pixels.
  List<VerticalLine> _buildExtremeLabels(
    BuildContext context,
    double Function(DateTime) timeToX,
    DateTime minTime,
    DateTime maxTime,
    ColorScheme colorScheme, {
    required double pixelsPerX,
  }) {
    if (widget.extremes == null || widget.extremes!.isEmpty) {
      return [];
    }

    final marks = TideChartColors.of(context);
    // Filter extremes within visible range
    final visibleExtremes = widget.extremes!
        .where((e) => !e.time.isBefore(minTime) && !e.time.isAfter(maxTime))
        .toList();

    return visibleExtremes.map((extreme) {
      final isHigh = extreme.type == TideExtremeType.high;
      final color = isHigh ? marks.high : marks.low;
      final label = isHigh ? 'H' : 'L';
      final timeStr = DateFormat(
        widget.timeFormat.pattern,
      ).format(_display(extreme.time));
      final displayHeight = DepthUnit.meters.convert(
        extreme.heightMeters,
        widget.depthUnit,
      );
      final heightStr =
          '${formatFixedForDisplay(displayHeight, 1)}${widget.depthUnit.symbol}';
      final text = ' $label $timeStr $heightStr ';
      final style = TextStyle(
        color: color,
        fontSize: TideChart.markFontSize,
        fontWeight: FontWeight.bold,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
      );

      final x = timeToX(extreme.time);
      final pixelX = x * pixelsPerX;
      final plotWidth = timeToX(maxTime) * pixelsPerX;
      final halfWidth = tideChartTextWidth(context, text, style) / 2;
      final side = pixelX - halfWidth < 0
          ? 1.0 // Too near the left edge: drawn to the right of its line.
          : pixelX + halfWidth > plotWidth
          ? -1.0 // Too near the right edge: drawn to the left of its line.
          : 0.0;

      return VerticalLine(
        x: x,
        color: Colors.transparent, // Invisible line, just for the label
        strokeWidth: 0,
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment(side, isHigh ? -1 : 1),
          // A label beside its line steps clear of the extreme's dot.
          padding: EdgeInsets.only(
            left: side > 0 ? tideChartSideLabelGap : 0,
            right: side < 0 ? tideChartSideLabelGap : 0,
            top: isHigh ? 0 : 4,
            bottom: isHigh ? 4 : 0,
          ),
          style: style,
          labelResolver: (line) => text,
        ),
      );
    }).toList();
  }
}
