import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';

import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_axis.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_overview_strip.dart';
import 'package:submersion/features/insights/presentation/widgets/date_axis.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart_input.dart';
import 'package:submersion/features/insights/presentation/formatters/trend_gap_label.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_break_band_painter.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_break_spots.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_reference_line.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_window_seater.dart';
import 'package:submersion/l10n/l10n_extension.dart';

part 'dive_trend_chart_touch.dart';

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

  /// Dot radius in raw mode; null draws the primary's size.
  final double? pointRadius;

  const TrendSeries({
    required this.label,
    required this.points,
    required this.color,
    this.pointRadius,
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
    this.gapThreshold = TrendGapThreshold.off,
    this.referenceLine,
  });

  /// Stretches with no dives longer than this collapse into a hatched band
  /// (issue #3251). Callers pass the diver's `trendGapThresholdProvider`.
  final TrendGapThreshold gapThreshold;

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

  /// A dashed horizontal marker, such as a threshold the diver set.
  final TrendReferenceLine? referenceLine;

  /// The diver's date order, threaded in by the caller rather than read from
  /// the ambient locale, so the axis and the tooltip match Manage - Units
  /// (#1512).
  final DateFormatPreference dateFormat;

  /// The window to show. A changed range re-seats the viewport; so does a
  /// changed data span, so a custom window keeps meaning the same dates.
  final TrendRange range;

  /// Called with the window the diver navigated to: [TrendRange.all] when
  /// unzoomed, otherwise a custom range of the visible dates. Not called when
  /// a navigation ends on the window already shown. Null when the caller does
  /// not keep the window.
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

  /// The x scale as last built, and what it was built from.
  TrendTimeScale _scale = TrendTimeScale.identity;
  Object? _scaleKey;

  /// Bucket index behind each drawn spot of the primary and each secondary
  /// data bar; null at a break's null spot.
  List<int?> _drawnSource = const [];
  List<List<int?>> _drawnSecondarySource = const [];

  /// Axis position of the pointer over the plot, from the touch callback,
  /// so the readout can tell a hover over a band from one over the data.
  double? _pointerAxisX;

  @visibleForTesting
  TrendTimeScale get debugScale => _scale;

  @visibleForTesting
  set debugPointerAxisX(double? x) => _pointerAxisX = x;

  /// The dive behind spot [spotIndex] of bar [barIndex], as a tap resolves
  /// it.
  @visibleForTesting
  String? debugDiveIdForSpot(int barIndex, int spotIndex) =>
      _diveIdForSpot(barIndex, spotIndex);

  double _x(DateTime date) => _scale.toAxis(date);

  /// The collapsed gap under the pointer, or null.
  TrendGapBreak? get _pointerInBreak {
    final x = _pointerAxisX;
    return x == null ? null : _scale.breakAt(x);
  }

  /// The dive behind spot [spotIndex] of bar [barIndex], or null for a
  /// break's null spot, an overlay bar, or a bucket of several dives (an
  /// aggregated bucket has no single dive to open).
  String? _diveIdForSpot(int barIndex, int spotIndex) {
    final List<TrendBucket> drawn;
    final List<int?> source;
    if (barIndex == 0) {
      drawn = _drawnBuckets;
      source = _drawnSource;
    } else if (_secondaryBarStart >= 0 &&
        barIndex >= _secondaryBarStart &&
        barIndex - _secondaryBarStart < _drawnSecondary.length) {
      drawn = _drawnSecondary[barIndex - _secondaryBarStart];
      source = _drawnSecondarySource[barIndex - _secondaryBarStart];
    } else {
      return null;
    }
    if (spotIndex < 0 || spotIndex >= source.length) return null;
    final bucket = source[spotIndex];
    return bucket == null ? null : drawn[bucket].diveId;
  }

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
    final chart = _buildChart(
      context,
      (box.width -
              trendChartPlotInsets.left -
              _yAxisNameSize -
              trendChartPlotInsets.right)
          .clamp(1.0, double.infinity),
    );
    return TrendChartInputLayer(
      box: box,
      viewport: _viewport,
      onViewportChanged: (vp) => setState(() => _viewport = vp),
      onNavigationEnd: _reportRange,
      child: chart,
    );
  }

  Widget _buildChart(BuildContext context, double plotWidth) {
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
    // Every plotted date feeds the scale, so no point (a month bucket dated
    // the 1st included) can land inside a band. Rebuilt only when what it
    // reads changes: pan and zoom rebuild on every pointer move.
    final scaleKey = (
      points,
      widget.secondarySeries,
      aggregation,
      widget.gapThreshold,
    );
    if (scaleKey != _scaleKey) {
      _scaleKey = scaleKey;
      // Per dive, every bucket is a dive, so the bucket dates are the lot.
      final raw = aggregation == TrendAggregation.none;
      _scale = TrendTimeScale.build([
        for (final b in allBuckets) b.date,
        if (!raw) ...[
          for (final p in points) p.date,
          for (final s in widget.secondarySeries)
            for (final p in s.points) p.date,
        ],
      ], widget.gapThreshold);
    }
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
    _viewport = _seater.seat(
      widget.range,
      _viewport,
      fullMin,
      fullMax,
      scale: _scale,
    );
    final visibleMin = fullMin + _viewport.offsetX * fullSpan;
    final visibleMax = visibleMin + fullSpan * _viewport.visibleWidth;
    final dateAxis = DateAxis.forAxisRange(
      visibleMin,
      visibleMax,
      scale: _scale,
      plotWidth: plotWidth,
      dateFormat: widget.dateFormat,
    );

    // The fits can run outside the bucket range, so the axis has to see them.
    // Computed once here and threaded into the axis, the legend labels and
    // the bars. Each of the three used to recompute them, so a large logbook
    // paid for the same O(n) fit three times on every rebuild, and pan/zoom
    // rebuilds on every pointer move.
    final smoothed = widget.showRollingMean
        ? rollingMean(
            points,
            periodOf: _scale.isIdentity ? null : _scale.periodOf,
          )
        : const <TrendDataPoint>[];
    final fit = widget.showLinearFit && points.isNotEmpty
        ? linearFit(points)
        : null;
    final yAxis = ChartAxis.forTrend(<double>[
      ...allBuckets.expand((b) => [b.min, b.max]),
      ...smoothed.map((p) => p.value),
      if (fit != null) ...[fit.valueAt(firstDate), fit.valueAt(lastDate)],
      // A threshold outside the data would otherwise sit off the plot.
      ?widget.referenceLine?.value,
    ]);

    // Only rebuilt when what it is drawn from changes: pan and zoom rebuild
    // the chart on every pointer move, and the data does not move with them.
    final overviewKey = (
      points,
      widget.secondarySeries,
      aggregation,
      fullMin,
      fullSpan,
      yAxis.min,
      yAxis.max,
    );
    if ((_viewport.isZoomed || _stripActive) && overviewKey != _overviewKey) {
      _overviewKey = overviewKey;
      final ySpan = yAxis.max - yAxis.min;
      // The strip plots the buckets the chart draws, not the raw dives: the
      // x range runs between bucket dates, and a dive later in the last
      // week or month would fall past it and pile up at the strip's edge.
      _overviewPoints = [
        for (final b in allBuckets)
          Offset(
            ((_x(b.date) - fullMin) / fullSpan).clamp(0.0, 1.0),
            ySpan <= 0 ? 0.5 : ((b.mean - yAxis.min) / ySpan).clamp(0.0, 1.0),
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
        child: Stack(
          children: [
            _lineChart(
              visibleMin: visibleMin,
              visibleMax: visibleMax,
              yAxis: yAxis,
              dateAxis: dateAxis,
              bars: bars,
              seriesLabels: seriesLabels,
              isRaw: isRaw,
              highlight: highlight,
            ),
            if (!_scale.isIdentity)
              _breakBands(context, visibleMin, visibleMax, plotWidth, height),
          ],
        ),
      ),
    );
  }

  Widget _lineChart({
    required double visibleMin,
    required double visibleMax,
    required ChartAxis yAxis,
    required DateAxis dateAxis,
    required List<LineChartBarData> bars,
    required List<String> seriesLabels,
    required bool isRaw,
    required ({DateTime start, DateTime end})? highlight,
  }) {
    final theme = Theme.of(context);
    return LineChart(
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
          getDrawingHorizontalLine: (value) =>
              FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
        ),
        lineBarsData: bars,
        extraLinesData: trendReferenceLines(context, widget.referenceLine),
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
  ///
  /// Every series is placed through [_scale] and lifts the pen at each
  /// collapsed gap (issue #3251); the bar indices are the same either way.
  List<LineChartBarData> _bars(
    BuildContext context,
    List<TrendBucket> buckets,
    Color color,
    bool isRaw,
    List<TrendDataPoint> smoothed,
    LinearFit? fit,
    List<List<TrendBucket>> secondary,
  ) {
    final primary = _bucketSpots(buckets, (b) => b.mean);
    _drawnSource = primary.source;
    final bars = <LineChartBarData>[_dataBar(primary.spots, color, isRaw)];

    if (!isRaw) {
      for (final selector in <double Function(TrendBucket)>[
        (b) => b.min,
        (b) => b.max,
      ]) {
        bars.add(
          LineChartBarData(
            spots: _bucketSpots(buckets, selector).spots,
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
      bars.add(
        LineChartBarData(
          spots: spotsAcrossBreaks(
            smoothed,
            (p) => p.date,
            (p) => p.value,
            _scale,
          ).spots,
          isCurved: false,
          color: widget.rollingColor ?? Theme.of(context).colorScheme.primary,
          barWidth: 2.2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    if (fit != null && buckets.isNotEmpty) {
      bars.add(
        LineChartBarData(
          // One fit, drawn only across the periods with dives, so it steps
          // at a band rather than sloping through years with no dives.
          spots: fitAcrossBreaks(fit, [
            for (final b in buckets) b.date,
          ], _scale),
          isCurved: false,
          color: widget.rateColor ?? Theme.of(context).colorScheme.tertiary,
          barWidth: 1.8,
          dashArray: const [6, 4],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    // Secondaries come last so every index above is unchanged by them.
    _secondaryBarStart = secondary.isEmpty ? -1 : bars.length;
    final secondarySource = <List<int?>>[];
    for (var i = 0; i < secondary.length; i++) {
      final placed = _bucketSpots(secondary[i], (b) => b.mean);
      secondarySource.add(placed.source);
      bars.add(
        _dataBar(
          placed.spots,
          widget.secondarySeries[i].color,
          isRaw,
          radius: widget.secondarySeries[i].pointRadius,
        ),
      );
    }
    _drawnSecondarySource = secondarySource;

    return bars;
  }

  ({List<FlSpot> spots, List<int?> source}) _bucketSpots(
    List<TrendBucket> buckets,
    double Function(TrendBucket) valueOf,
  ) => spotsAcrossBreaks(buckets, (b) => b.date, valueOf, _scale);

  /// A per-dive series: dots only in raw mode (a stroke between two dives
  /// eight months apart would assert something happened in between), dotted
  /// line when aggregated so the buckets stay findable without hovering.
  LineChartBarData _dataBar(
    List<FlSpot> spots,
    Color color,
    bool isRaw, {
    double? radius,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: isRaw ? 0 : 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: radius ?? (isRaw ? 2.2 : 3),
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
