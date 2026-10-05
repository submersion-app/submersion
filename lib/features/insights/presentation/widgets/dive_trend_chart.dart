import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';

import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_axis.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';
import 'package:submersion/features/insights/presentation/widgets/date_axis.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart_input.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_window_seater.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A per-dive trend chart on a real date axis.
///
/// Distinct from `TrendLineChart`, which plots `FlSpot(index, value)` and so
/// draws a three-month gap and a three-week gap identically. That is fine for
/// a dense monthly series; it is not fine for individual dives, which cluster
/// hard around trips (issue #299).
///
/// Layers, all sharing one set of axes:
///  - the data, as dots when raw or a mean line when aggregated
///  - a rolling mean, optional
///  - a linear fit, optional
///
/// fl_chart's ScatterChart is deliberately not used: it cannot carry the
/// overlay line series alongside the points.
/// A named series drawn beside the primary points on the same axes, in its
/// own colour (condition phase 4a: one line per cell slot, the dives with
/// an issue on a temperature trend).
class TrendSeries {
  final String label;
  final List<TrendDataPoint> points;
  final Color color;

  const TrendSeries({
    required this.label,
    required this.points,
    required this.color,
  });
}

class DiveTrendChart extends StatefulWidget {
  const DiveTrendChart({
    super.key,
    required this.points,
    this.secondarySeries = const [],
    this.highlightRange,
    this.aggregation = TrendAggregation.none,
    this.showRollingMean = false,
    this.showLinearFit = false,
    this.pointColor,
    this.rollingColor,
    this.rateColor,
    this.yAxisLabel,
    this.height = 200,
    this.valueFormatter,
    this.yAxisFormatter,
    this.chartId,
    this.onDiveSelected,
    this.dateFormat = DateFormatPreference.mmmDYYYY,
    this.range = TrendRange.all,
    this.onRangeChanged,
  });

  /// Raw per-dive points, in any order. Never pre-aggregated by the caller.
  /// May be empty when [secondarySeries] carries the data.
  final List<TrendDataPoint> points;

  /// Extra series on the same axes, bucketed like [points] and named in
  /// the tooltip. Each draws as dots (raw) or a mean line (aggregated);
  /// the min/max bars and the spread band belong to the primary alone,
  /// so a series whose range matters should be the primary. Index 0 of
  /// the drawn bars stays the primary so tap and tooltip indices are
  /// stable.
  final List<TrendSeries> secondarySeries;

  /// A time span shaded behind the series, for a finding's evidence window.
  final ({DateTime start, DateTime end})? highlightRange;

  /// The diver's date order, threaded in by the caller rather than read from
  /// the ambient locale, so the axis and the tooltip match Manage - Units
  /// (#1512).
  final DateFormatPreference dateFormat;

  /// The window to show. A changed range re-seats the viewport; so does a
  /// changed data span, so a custom window keeps meaning the same dates.
  final TrendRange range;

  /// Called with the window the diver navigated to: [TrendRange.all] when
  /// unzoomed, otherwise a custom range of the visible dates. Null when the
  /// caller does not keep the window.
  final ValueChanged<TrendRange>? onRangeChanged;

  final TrendAggregation aggregation;
  final bool showRollingMean;
  final bool showLinearFit;
  final Color? pointColor;
  final Color? rollingColor;
  final Color? rateColor;
  final String? yAxisLabel;
  final double height;
  final String Function(double)? valueFormatter;
  final String Function(double)? yAxisFormatter;

  /// Distinguishes this chart's zoom controls from others on the page.
  final String? chartId;

  /// Called with the dive behind a tapped point. Only ever fires in raw
  /// mode: a bucket stands for several dives, so there is nothing single to
  /// open. Null leaves points inert.
  final void Function(String diveId)? onDiveSelected;

  @override
  State<DiveTrendChart> createState() => _DiveTrendChartState();
}

class _DiveTrendChartState extends State<DiveTrendChart> {
  /// Visible window over the time axis. Y is never zoomed: a trend chart's
  /// interesting axis is time, and holding the value axis still keeps the
  /// grid readable while panning.
  ChartViewport _viewport = ChartViewport.reset;

  /// Buckets as last drawn, so a tap on the data series can resolve which
  /// dive it landed on.
  List<TrendBucket> _drawnBuckets = const [];

  /// Secondary buckets as last drawn, parallel to [_secondaryBarStart].
  List<List<TrendBucket>> _drawnSecondary = const [];

  /// Index of the first secondary bar in the drawn bars, or -1.
  int _secondaryBarStart = -1;

  /// Column widths for the monospace tooltip rows, as on the profile chart.
  static const _tooltipLabelWidth = 16;
  static const _tooltipValueWidth = 12;

  static double _x(DateTime date) => date.millisecondsSinceEpoch.toDouble();

  /// Room fl_chart reserves for the rotated y-axis name, left of the tick
  /// labels. The overview strip has to clear it to line up with the plot.
  double get _yAxisNameSize => widget.yAxisLabel != null ? 20 : 0;

  /// True while the strip is being dragged, so a drag that zooms all the way
  /// out keeps its strip until the gesture ends.
  bool _stripActive = false;

  /// The strip's points, rebuilt with the chart only while it is showing.
  List<Offset> _overviewPoints = const [];

  /// What [_overviewPoints] was last built from; lists compare by identity.
  Object? _overviewKey;

  final TrendWindowSeater _seater = TrendWindowSeater();

  /// Hands the settled window to [DiveTrendChart.onRangeChanged].
  void _reportRange() {
    final onRangeChanged = widget.onRangeChanged;
    if (onRangeChanged == null) return;
    final next = _seater.report(_viewport);
    if (next != null && next != widget.range) onRangeChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty &&
        widget.secondarySeries.every((s) => s.points.isEmpty)) {
      return _EmptyChart(height: widget.height);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, widget.height);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _interactiveChart(context, box),
            if (_viewport.isZoomed || _stripActive)
              Padding(
                padding: EdgeInsets.only(
                  left: trendChartPlotInsets.left + _yAxisNameSize,
                  top: 6,
                ),
                child: ChartOverviewStrip(
                  points: _overviewPoints,
                  viewport: _viewport,
                  onViewportChanged: (vp) => setState(() => _viewport = vp),
                  onChangeStart: () => setState(() => _stripActive = true),
                  onChangeEnd: () {
                    setState(() => _stripActive = false);
                    _reportRange();
                  },
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ChartZoomControls(
                keyPrefix: widget.chartId == null
                    ? null
                    : 'trend-${widget.chartId}',
                zoomLevel: _viewport.zoom,
                minZoom: ChartViewport.minZoom,
                maxZoom: _viewport.zoomLimit,
                // No cursor to anchor on, so the buttons zoom about the middle
                // of the visible window.
                onZoomIn: () {
                  setState(() => _viewport = _viewport.zoomedAt(0.5, 0, 1.5));
                  _reportRange();
                },
                onZoomOut: () {
                  setState(
                    () => _viewport = _viewport.zoomedAt(0.5, 0, 1 / 1.5),
                  );
                  _reportRange();
                },
                onResetZoom: () {
                  setState(
                    () => _viewport = ChartViewport.reset.withZoomLimit(
                      _viewport.zoomLimit,
                    ),
                  );
                  _reportRange();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _interactiveChart(BuildContext context, Size box) {
    // Built before the layer is handed the viewport: building the chart can
    // re-seat the viewport (a new range or a new data span).
    final chart = _buildChart(context);
    return TrendChartInputLayer(
      box: box,
      viewport: _viewport,
      onViewportChanged: (vp) => setState(() => _viewport = vp),
      onNavigationEnd: _reportRange,
      child: chart,
    );
  }

  Widget _buildChart(BuildContext context) {
    final points = widget.points;
    final aggregation = widget.aggregation;
    final height = widget.height;
    final yAxisLabel = widget.yAxisLabel;

    final theme = Theme.of(context);
    final color = widget.pointColor ?? theme.colorScheme.primary;

    final buckets = aggregate(points, aggregation);
    _drawnBuckets = buckets;
    final secondary = [
      for (final s in widget.secondarySeries) aggregate(s.points, aggregation),
    ];
    _drawnSecondary = secondary;
    // The x range spans every drawn bucket; the primary may be empty when
    // the secondaries carry the data.
    // One pass for the ends: sorting every bucket of every series just to
    // read its first and last would cost n log n on each pan and zoom.
    final allBuckets = [...buckets, ...secondary.expand((b) => b)];
    var firstDate = allBuckets.first.date;
    var lastDate = firstDate;
    for (final b in allBuckets) {
      if (b.date.isBefore(firstDate)) firstDate = b.date;
      if (b.date.isAfter(lastDate)) lastDate = b.date;
    }

    // The window the viewport exposes, not the whole series. Ticks are chosen
    // from the visible span so a chart zoomed into a few weeks stops being
    // labelled by year.
    final fullMin = _x(firstDate);
    final fullMax = _x(lastDate);
    final fullSpan = (fullMax - fullMin).clamp(1.0, double.infinity);
    // Runs inside build, before anything reads the viewport.
    _viewport = _seater.seat(widget.range, _viewport, fullMin, fullMax);
    final visibleMin = fullMin + _viewport.offsetX * fullSpan;
    final visibleMax = visibleMin + fullSpan * _viewport.visibleWidth;
    final dateAxis = DateAxis.forRange(
      DateTime.fromMillisecondsSinceEpoch(visibleMin.toInt(), isUtc: true),
      DateTime.fromMillisecondsSinceEpoch(visibleMax.toInt(), isUtc: true),
      dateFormat: widget.dateFormat,
    );

    // The fits can run outside the bucket range, so the axis has to see them.
    // Computed once here and threaded into the axis, the legend labels and
    // the bars. Each of the three used to recompute them, so a large logbook
    // paid for the same O(n) fit three times on every rebuild, and pan/zoom
    // rebuilds on every pointer move.
    final smoothed = widget.showRollingMean
        ? rollingMean(points)
        : const <TrendDataPoint>[];
    final fit = widget.showLinearFit && points.isNotEmpty
        ? linearFit(points)
        : null;
    final yAxis = ChartAxis.forTrend(<double>[
      ...allBuckets.expand((b) => [b.min, b.max]),
      ...smoothed.map((p) => p.value),
      if (fit != null) ...[fit.valueAt(firstDate), fit.valueAt(lastDate)],
    ]);

    // Only rebuilt when what it is drawn from changes: pan and zoom rebuild
    // the chart on every pointer move, and the data does not move with them.
    final overviewKey = (
      points,
      widget.secondarySeries,
      fullMin,
      fullSpan,
      yAxis.min,
      yAxis.max,
    );
    if ((_viewport.isZoomed || _stripActive) && overviewKey != _overviewKey) {
      _overviewKey = overviewKey;
      final ySpan = yAxis.max - yAxis.min;
      _overviewPoints = [
        for (final p in [
          ...points,
          ...widget.secondarySeries.expand((s) => s.points),
        ])
          Offset(
            ((_x(p.date) - fullMin) / fullSpan).clamp(0.0, 1.0),
            ySpan <= 0 ? 0.5 : ((p.value - yAxis.min) / ySpan).clamp(0.0, 1.0),
          ),
      ];
    }

    final isRaw = aggregation == TrendAggregation.none;
    final bars = _bars(
      context,
      buckets,
      color,
      isRaw,
      smoothed,
      fit,
      secondary,
    );
    final seriesLabels = _seriesLabels(context, isRaw, smoothed, fit);
    final highlight = widget.highlightRange;

    // Every plotted point, secondaries included: the condition charts
    // leave the primary empty and draw all their data as secondaries.
    final pointCount =
        points.length +
        widget.secondarySeries.fold<int>(0, (n, s) => n + s.points.length);
    return Semantics(
      label: yAxisLabel != null
          ? context.l10n.insights_chart_trendSemanticLabelWithAxis(
              pointCount,
              yAxisLabel,
            )
          : context.l10n.insights_chart_trendSemanticLabel(pointCount),
      child: SizedBox(
        height: height,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: visibleMin,
            maxX: visibleMax,
            clipData: const FlClipData.horizontal(),
            minY: yAxis.min,
            maxY: yAxis.max,
            lineTouchData: _touchData(context, bars, seriesLabels),
            titlesData: _titles(context, dateAxis, yAxis),
            // Framed like the dive profile chart: an unbounded plot floats
            // on the card with nothing to read the axes against.
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yAxis.interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outlineVariant,
                strokeWidth: 1,
              ),
            ),
            lineBarsData: bars,
            betweenBarsData: _bands(context, isRaw),
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: [
                if (highlight != null)
                  VerticalRangeAnnotation(
                    x1: _x(highlight.start),
                    x2: _x(highlight.end),
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Names every series in the order [_bars] builds them, so the tooltip can
  /// label each value instead of listing bare numbers.
  List<String> _seriesLabels(
    BuildContext context,
    bool isRaw,
    List<TrendDataPoint> smoothed,
    LinearFit? fit,
  ) {
    final l10n = context.l10n;
    final mode = switch (widget.aggregation) {
      TrendAggregation.none => l10n.insights_trend_aggregation_perDive,
      TrendAggregation.weekly => l10n.insights_trend_aggregation_weekly,
      TrendAggregation.monthly => l10n.insights_trend_aggregation_monthly,
    };
    return <String>[
      mode,
      if (!isRaw) ...[
        l10n.insights_trend_tooltip_lowest,
        l10n.insights_trend_tooltip_highest,
      ],
      if (smoothed.isNotEmpty) l10n.insights_trend_legend_rollingAverage,
      if (fit != null) l10n.insights_trend_legend_rate,
      for (final s in widget.secondarySeries) s.label,
    ];
  }

  /// Index 0 is always the data series. When aggregating, indices 1 and 2 are
  /// the invisible bucket min and max that [_bands] fills between.
  List<LineChartBarData> _bars(
    BuildContext context,
    List<TrendBucket> buckets,
    Color color,
    bool isRaw,
    List<TrendDataPoint> smoothed,
    LinearFit? fit,
    List<List<TrendBucket>> secondary,
  ) {
    final bars = <LineChartBarData>[_dataBar(buckets, color, isRaw)];

    if (!isRaw) {
      for (final selector in <double Function(TrendBucket)>[
        (b) => b.min,
        (b) => b.max,
      ]) {
        bars.add(
          LineChartBarData(
            spots: buckets
                .map((b) => FlSpot(_x(b.date), selector(b)))
                .toList(growable: false),
            isCurved: false,
            barWidth: 0,
            color: Colors.transparent,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    // Both fits read the RAW dives, never the buckets. Fitting over monthly
    // means would smooth twice, and the line would visibly move when the
    // dropdown changed, implying the underlying trend had changed when only
    // the drawing did.
    if (smoothed.isNotEmpty) {
      {
        bars.add(
          LineChartBarData(
            spots: smoothed
                .map((p) => FlSpot(_x(p.date), p.value))
                .toList(growable: false),
            isCurved: false,
            color: widget.rollingColor ?? Theme.of(context).colorScheme.primary,
            barWidth: 2.2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    if (fit != null && buckets.isNotEmpty) {
      {
        final first = buckets.first.date;
        final last = buckets.last.date;
        bars.add(
          LineChartBarData(
            spots: [
              FlSpot(_x(first), fit.valueAt(first)),
              FlSpot(_x(last), fit.valueAt(last)),
            ],
            isCurved: false,
            color: widget.rateColor ?? Theme.of(context).colorScheme.tertiary,
            barWidth: 1.8,
            dashArray: const [6, 4],
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    // Secondaries come last so every index above is unchanged by them.
    _secondaryBarStart = secondary.isEmpty ? -1 : bars.length;
    for (var i = 0; i < secondary.length; i++) {
      bars.add(_dataBar(secondary[i], widget.secondarySeries[i].color, isRaw));
    }

    return bars;
  }

  /// A per-dive series: dots only in raw mode (a stroke between two dives
  /// eight months apart would assert something happened in between), dotted
  /// line when aggregated so the buckets stay findable without hovering.
  LineChartBarData _dataBar(
    List<TrendBucket> buckets,
    Color color,
    bool isRaw,
  ) {
    return LineChartBarData(
      spots: buckets
          .map((b) => FlSpot(_x(b.date), b.mean))
          .toList(growable: false),
      isCurved: false,
      color: color,
      barWidth: isRaw ? 0 : 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: isRaw ? 2.2 : 3,
          color: color.withValues(alpha: isRaw ? 0.7 : 1),
          strokeWidth: 0,
        ),
      ),
    );
  }

  /// Fills between the min and max series so an aggregated chart still shows
  /// the spread. Smoothing must not put back the hiding this issue is about.
  List<BetweenBarsData> _bands(BuildContext context, bool isRaw) {
    if (isRaw) return const [];
    final color = widget.pointColor ?? Theme.of(context).colorScheme.primary;
    return [
      BetweenBarsData(
        fromIndex: 1,
        toIndex: 2,
        color: color.withValues(alpha: 0.15),
      ),
    ];
  }

  LineTouchData _touchData(
    BuildContext context,
    List<LineChartBarData> bars,
    List<String> seriesLabels,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dataBar = bars.first;
    final secondaryBars = _secondaryBarStart < 0
        ? const <LineChartBarData>[]
        : bars.sublist(_secondaryBarStart);
    return LineTouchData(
      // Generous, so the readout follows the pointer anywhere over the plot
      // rather than only within a few pixels of a dot.
      touchSpotThreshold: 1000,
      // Full-height hover line. fl_chart's default stops at the touched spot,
      // so for a series sitting near zero it is a few pixels tall and reads as
      // no line at all.
      getTouchLineStart: (_, _) => double.negativeInfinity,
      getTouchLineEnd: (_, _) => double.infinity,
      // Highlight the touched point on the data series only. The band bounds
      // and the fitted overlays would each contribute their own dot and line,
      // stacking several markers on one touch.
      getTouchedSpotIndicator: (barData, spotIndexes) {
        if (!identical(barData, dataBar) &&
            !secondaryBars.any((b) => identical(b, barData))) {
          return List<TouchedSpotIndicatorData?>.filled(
            spotIndexes.length,
            null,
          );
        }
        return defaultTouchedIndicators(barData, spotIndexes);
      },
      touchCallback: (event, response) {
        if (event is! FlTapUpEvent) return;
        final onDiveSelected = widget.onDiveSelected;
        if (onDiveSelected == null) return;
        // Every series reports its own nearest spot, so the first one
        // listed need not be the touched one: take the nearest of all.
        final spot = nearestTouchedDataSpot(
          response?.lineBarSpots ?? const [],
          (barIndex) =>
              barIndex == 0 ||
              (_secondaryBarStart >= 0 &&
                  barIndex >= _secondaryBarStart &&
                  barIndex - _secondaryBarStart < _drawnSecondary.length),
        );
        if (spot == null) return;
        final List<TrendBucket> drawn;
        if (spot.barIndex == 0) {
          drawn = _drawnBuckets;
        } else if (_secondaryBarStart >= 0 &&
            spot.barIndex >= _secondaryBarStart &&
            spot.barIndex - _secondaryBarStart < _drawnSecondary.length) {
          drawn = _drawnSecondary[spot.barIndex - _secondaryBarStart];
        } else {
          return;
        }
        if (spot.spotIndex < 0 || spot.spotIndex >= drawn.length) return;
        // Only a bucket standing for exactly one dive can be opened; an
        // aggregated bucket has no single dive behind it.
        final diveId = drawn[spot.spotIndex].diveId;
        if (diveId != null) onDiveSelected(diveId);
      },
      touchTooltipData: LineTouchTooltipData(
        // Wide enough for a labelled row such as "Rolling avg 85 psi/min"
        // without wrapping. Narrower readouts still size to their content;
        // this is only a cap, matching the dive profile chart.
        maxContentWidth: 320,
        getTooltipColor: (_) => colorScheme.inverseSurface,
        // Above the plot rather than over it: the bubble used to land on the
        // very point it was describing.
        showOnTopOfTheChartBoxArea: true,
        tooltipMargin: 0,
        fitInsideHorizontally: true,
        fitInsideVertically: false,
        getTooltipItems: (touchedSpots) {
          if (touchedSpots.isEmpty) return const <LineTooltipItem?>[];
          // Matches the dive profile chart's readout: monospace with tabular
          // figures so the value column lines up between rows.
          final style = TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 14,
            color: colorScheme.onInverseSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
          final date = DateTime.fromMillisecondsSinceEpoch(
            touchedSpots.first.x.toInt(),
            isUtc: true,
          );

          return [
            for (var i = 0; i < touchedSpots.length; i++)
              if (i == 0)
                LineTooltipItem(
                  DateFormat(widget.dateFormat.pattern).format(date),
                  style,
                  children: [
                    for (final spot in touchedSpots)
                      TextSpan(
                        text:
                            '\n${DiveProfileChart.tooltipRowText(spot.barIndex < seriesLabels.length ? seriesLabels[spot.barIndex] : '', widget.valueFormatter?.call(spot.y) ?? spot.y.toStringAsFixed(1), _tooltipLabelWidth, _tooltipValueWidth)}',
                        style: style,
                      ),
                  ],
                  textAlign: TextAlign.start,
                )
              else
                null,
          ];
        },
      ),
    );
  }

  FlTitlesData _titles(
    BuildContext context,
    DateAxis dateAxis,
    ChartAxis yAxis,
  ) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          // fl_chart samples this interval to decide where to ask for a
          // label. Leaving it null lets fl_chart pick its own values, which
          // then never match a nominated tick and the axis renders blank.
          interval: dateAxis.labelInterval,
          getTitlesWidget: (value, meta) {
            final label = dateAxis.labelFor(value, step: meta.appliedInterval);
            if (label == null) return const Text('');
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: widget.yAxisLabel != null
            ? Text(
                widget.yAxisLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        axisNameSize: _yAxisNameSize,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          interval: yAxis.interval,
          getTitlesWidget: (value, meta) {
            final formatter = widget.yAxisFormatter ?? widget.valueFormatter;
            return Text(
              formatter?.call(value) ?? value.toStringAsFixed(0),
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}

/// Same empty state as `TrendLineChart`, so a chart with no dives reads the
/// same wherever it appears.
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.insights_chart_noTrendData,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The spot nearest the tap among [spots] on a data series ([isData] by
/// bar index), or null. fl_chart reports one nearest spot per series,
/// band bounds and overlays included, in bar order.
@visibleForTesting
TouchLineBarSpot? nearestTouchedDataSpot(
  List<TouchLineBarSpot> spots,
  bool Function(int barIndex) isData,
) {
  TouchLineBarSpot? nearest;
  for (final s in spots) {
    if (!isData(s.barIndex)) continue;
    if (nearest == null || s.distance < nearest.distance) nearest = s;
  }
  return nearest;
}
