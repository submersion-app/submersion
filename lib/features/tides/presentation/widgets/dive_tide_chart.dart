import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/tides/domain/services/dive_tide_window.dart';
import 'package:submersion/features/tides/presentation/widgets/dive_tide_chart_painter.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart_colors.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_chart_ticks.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The predicted tide across the day around one dive.
///
/// Plots the real tide curve for [window], marks each high and low with its
/// time and height, and shades the dive from its entry to its exit. Positions
/// are real instants; [displayTime] maps an instant to the clock the labels
/// are printed in (the dive site's wall clock).
///
/// The widget takes the width it is given and sets its own height.
class DiveTideChart extends StatelessWidget {
  const DiveTideChart({
    super.key,
    required this.window,
    required this.units,
    required this.displayTime,
    this.diveDuration,
    this.plotHeight = defaultPlotHeight,
  });

  final DiveTideWindow window;

  /// The diver's unit and clock settings.
  final UnitFormatter units;

  /// Maps a plotted instant to the clock its labels are printed in.
  final DateTime Function(DateTime instant) displayTime;

  /// How long the dive ran, which sets the width of its band; null marks
  /// the entry alone.
  final Duration? diveDuration;

  /// Height of the area the curve is drawn in, without the axis or the
  /// dive marker above it.
  final double plotHeight;

  static const double defaultPlotHeight = 160;

  /// Size of the labels on the highs, the lows and the dive marker.
  static const double labelFontSize = 14;

  /// Size of the axis tick labels.
  static const double axisFontSize = 14;

  static const double _rightPadding = 8;
  static const double _axisGap = 6;
  static const double _labelGap = 4;

  /// The height the chart takes in [context], for holding its place while
  /// the tide is still being computed.
  static double heightOf(
    BuildContext context, {
    double plotHeight = defaultPlotHeight,
  }) {
    final styles = _Styles.of(context);
    return styles.pillHeight +
        _axisGap +
        plotHeight +
        _labelGap +
        styles.axisLineHeight;
  }

  @override
  Widget build(BuildContext context) {
    if (window.predictions.length < 2) return const SizedBox.shrink();

    final l10n = context.l10n;
    final timeFormat = DateFormat(units.settings.timeFormat.pattern);
    final depthUnit = units.settings.depthUnit;
    String timeOf(DateTime instant) => timeFormat.format(displayTime(instant));

    final summary = window.extremes.isEmpty
        ? l10n.tides_noExtremesData
        : window.extremes
              .map(
                (extreme) => l10n.tides_semantic_extremeItem(
                  extreme.type == TideExtremeType.high
                      ? l10n.tides_label_high
                      : l10n.tides_label_low,
                  timeOf(extreme.time),
                  formatFixedForDisplay(
                    DepthUnit.meters.convert(extreme.heightMeters, depthUnit),
                    1,
                  ),
                  depthUnit.symbol,
                ),
              )
              .join('. ');

    return Semantics(
      label: l10n.tides_semantic_tideChart(summary),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _buildChart(context, constraints.maxWidth, timeOf),
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    double width,
    String Function(DateTime instant) timeOf,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final colors = TideChartColors.of(context);
    final styles = _Styles.of(context);
    final depthUnit = units.settings.depthUnit;

    // Heights, in metres: the curve plus the refined extremes, which can sit
    // a little past the nearest sample.
    final heights = [
      for (final p in window.predictions) p.heightMeters,
      for (final e in window.extremes) e.heightMeters,
    ];
    final minHeight = heights.reduce(math.min);
    final maxHeight = heights.reduce(math.max);
    final heightRange = math.max(maxHeight - minHeight, 0.01);

    // The curve keeps clear of the plot's top and bottom by a label's
    // height, so the label over a high and under a low stays inside it.
    final inset =
        styles.markLineHeight +
        DiveTideChartPainter.extremeDotRadius +
        _labelGap +
        2;
    final plotTop = styles.pillHeight + _axisGap;
    final plotBottom = plotTop + plotHeight;
    final curveSpan = math.max(plotHeight - 2 * inset, 1.0);
    final metersPerPixel = heightRange / curveSpan;
    double yOf(double meters) =>
        plotBottom - inset - (meters - minHeight) / metersPerPixel;

    // Height axis, in the diver's unit, over what the plot actually shows.
    double shown(double meters) => DepthUnit.meters.convert(meters, depthUnit);
    final axis = tideHeightTicks(
      shown(minHeight - (inset - _axisGap) * metersPerPixel),
      shown(maxHeight + (inset - _axisGap) * metersPerPixel),
    );
    final heightLabels = [
      for (final tick in axis.ticks) formatFixedForDisplay(tick, axis.decimals),
    ];
    final plotLeft =
        heightLabels
            .map((label) => styles.measure(label, styles.axis).width)
            .fold(0.0, math.max) +
        _axisGap;
    final plotRight = math.max(width - _rightPadding, plotLeft + 1);
    final plot = Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom);

    final windowMicros = math.max(
      window.end.difference(window.start).inMicroseconds,
      1,
    );
    double xOf(DateTime instant) =>
        plot.left +
        instant.difference(window.start).inMicroseconds /
            windowMicros *
            plot.width;

    final children = <Widget>[];

    // Height axis labels.
    final gridYs = <double>[];
    for (var i = 0; i < axis.ticks.length; i++) {
      final y = yOf(depthUnit.convert(axis.ticks[i], DepthUnit.meters));
      gridYs.add(y);
      children.add(
        Positioned(
          left: 0,
          width: plot.left - _axisGap,
          top: y - styles.axisLineHeight / 2,
          child: Text(
            heightLabels[i],
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            style: styles.axis,
          ),
        ),
      );
    }

    // Time axis: round hours of the site clock, the day's name at midnight.
    final stepHours = tideTimeStepHours(
      plotWidth: plot.width,
      labelWidth: styles
          .measure(_formatAt(DateTime.utc(2000, 1, 1, 22)), styles.axis)
          .width,
      windowHours: math.max(window.end.difference(window.start).inHours, 1),
    );
    final tickXs = <double>[];
    final midnightXs = <double>[];
    var lastLabelRight = double.negativeInfinity;
    for (final tick in wallClockHourTicks(
      start: window.start,
      end: window.end,
      stepHours: stepHours,
      toSite: displayTime,
    )) {
      final x = xOf(tick);
      final wall = displayTime(tick);
      final isMidnight = wall.hour == 0 && wall.minute == 0;
      (isMidnight ? midnightXs : tickXs).add(x);

      final label = isMidnight ? DateFormat('EEE').format(wall) : timeOf(tick);
      final style = isMidnight ? styles.axisStrong : styles.axis;
      final labelWidth = styles.measure(label, style).width;
      final left = _clamp(x - labelWidth / 2, 0, width - labelWidth);
      if (left < lastLabelRight + _axisGap) continue;
      lastLabelRight = left + labelWidth;
      children.add(
        Positioned(
          left: left,
          top: plot.bottom + _labelGap,
          child: Text(label, maxLines: 1, softWrap: false, style: style),
        ),
      );
    }

    // Highs and lows. A full label names the height too; a narrow chart
    // keeps the time alone, since the list under the chart has the heights.
    String letterOf(TideExtreme extreme) =>
        extreme.type == TideExtremeType.high ? 'H' : 'L';
    final fullLabels = [
      for (final extreme in window.extremes)
        '${letterOf(extreme)} ${timeOf(extreme.time)} · '
            '${units.formatDepth(extreme.heightMeters)}',
    ];
    final widestFull =
        fullLabels
            .map((label) => styles.measure(label, styles.mark).width)
            .fold(0.0, math.max) +
        2 * _markPadding;
    // Two highs (or two lows) sit about half the window apart.
    final useFull = widestFull + 3 * _labelGap <= plot.width / 2;
    // Each label sits on a patch of the card's own colour, so the entry
    // line, the dive's band and the grid never run through its text: a dive
    // at slack water puts the entry right beside a high or a low.
    final backdrop = backdropColorOf(context);
    final labelBackdrop = BoxDecoration(
      color: backdrop.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(4),
    );

    final extremeDots = <({Offset at, Color color})>[];
    for (var i = 0; i < window.extremes.length; i++) {
      final extreme = window.extremes[i];
      final isHigh = extreme.type == TideExtremeType.high;
      final color = isHigh ? colors.high : colors.low;
      final at = Offset(xOf(extreme.time), yOf(extreme.heightMeters));
      extremeDots.add((at: at, color: color));

      final label = useFull
          ? fullLabels[i]
          : '${letterOf(extreme)} ${timeOf(extreme.time)}';
      final labelWidth =
          styles.measure(label, styles.mark).width + 2 * _markPadding;
      const reach = DiveTideChartPainter.extremeDotRadius + _labelGap;
      children.add(
        Positioned(
          left: _clamp(
            at.dx - labelWidth / 2,
            plot.left,
            plot.right - labelWidth,
          ),
          top: isHigh ? at.dy - reach - styles.markLineHeight : at.dy + reach,
          child: DecoratedBox(
            decoration: labelBackdrop,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _markPadding),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: styles.mark.copyWith(color: color),
              ),
            ),
          ),
        ),
      );
    }

    // The dive: a marker above the plot at its entry.
    final entryX = xOf(window.entry);
    final entryHeight = window.heightAt(window.entry);
    final duration = diveDuration;
    final exitX = duration == null || duration <= Duration.zero
        ? null
        : xOf(window.entry.add(duration));
    final entryLabel = timeOf(window.entry);
    final pillWidth =
        2 * _pillPadding +
        styles.pillIconSize +
        _labelGap +
        styles.measure(entryLabel, styles.mark).width;
    children.add(
      Positioned(
        left: _clamp(entryX - pillWidth / 2, 0, width - pillWidth),
        top: 0,
        height: styles.pillHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.dive,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pillPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.scuba_diving,
                  size: styles.pillIconSize,
                  color: colors.onDive,
                ),
                const SizedBox(width: _labelGap),
                Text(
                  entryLabel,
                  maxLines: 1,
                  softWrap: false,
                  style: styles.mark.copyWith(color: colors.onDive),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: width,
      height: plot.bottom + _labelGap + styles.axisLineHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DiveTideChartPainter(
                plot: plot,
                curve: [
                  for (final p in window.predictions)
                    Offset(xOf(p.time), yOf(p.heightMeters)),
                ],
                gridYs: gridYs,
                tickXs: tickXs,
                midnightXs: midnightXs,
                extremes: extremeDots,
                entryX: entryX,
                entryY: entryHeight == null ? null : yOf(entryHeight),
                exitX: exitX,
                curveColor: scheme.primary,
                gridColor: scheme.outlineVariant.withValues(alpha: 0.5),
                midnightColor: scheme.outlineVariant,
                diveColor: colors.dive,
                ringColor: backdrop,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  static const double _pillPadding = 8;

  /// Room either side of a high or low label, inside its backdrop.
  static const double _markPadding = 3;

  String _formatAt(DateTime wallClock) =>
      DateFormat(units.settings.timeFormat.pattern).format(wallClock);

  /// [value] held between [min] and [max]; [min] wins when the label is
  /// wider than the room it has.
  static double _clamp(double value, double min, double max) =>
      max < min ? min : value.clamp(min, max);
}

/// The chart's text styles, resolved against the ambient text style and
/// text scale so that a measured width matches what a [Text] lays out.
class _Styles {
  _Styles._({
    required this.mark,
    required this.axis,
    required this.axisStrong,
    required this.scaler,
    required this.direction,
  }) : markLineHeight = _measure('0', mark, scaler, direction).height,
       axisLineHeight = _measure('0', axis, scaler, direction).height;

  factory _Styles.of(BuildContext context) {
    final theme = Theme.of(context);
    final base = DefaultTextStyle.of(context).style;
    final mark = base
        .merge(theme.textTheme.labelLarge)
        .copyWith(
          fontSize: DiveTideChart.labelFontSize,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0,
        );
    final axis = base
        .merge(theme.textTheme.bodyMedium)
        .copyWith(
          fontSize: DiveTideChart.axisFontSize,
          height: 1.2,
          letterSpacing: 0,
          color: theme.colorScheme.onSurfaceVariant,
        );
    return _Styles._(
      mark: mark,
      axis: axis,
      axisStrong: axis.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
    );
  }

  /// Labels on the highs, the lows and the dive marker.
  final TextStyle mark;

  /// Axis tick labels, and the bolder one that names a day.
  final TextStyle axis;
  final TextStyle axisStrong;

  final TextScaler scaler;
  final TextDirection direction;
  final double markLineHeight;
  final double axisLineHeight;

  double get pillHeight => markLineHeight + 6;
  double get pillIconSize => scaler.scale(DiveTideChart.labelFontSize);

  Size measure(String text, TextStyle style) =>
      _measure(text, style, scaler, direction);

  static Size _measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }
}
