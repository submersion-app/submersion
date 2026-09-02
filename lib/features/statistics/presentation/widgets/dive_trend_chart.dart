import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_touch_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';

import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/chart_axis.dart';
import 'package:submersion/features/statistics/presentation/widgets/date_axis.dart';
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
class DiveTrendChart extends StatefulWidget {
  const DiveTrendChart({
    super.key,
    required this.points,
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
  });

  /// Raw per-dive points, in any order. Never pre-aggregated by the caller.
  final List<TrendDataPoint> points;

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

  ChartViewport _gestureStartViewport = ChartViewport.reset;

  /// Buckets as last drawn, so a tap on the data series can resolve which
  /// dive it landed on.
  List<TrendBucket> _drawnBuckets = const [];
  PointerDeviceKind _activePointerKind = PointerDeviceKind.mouse;
  int _activePointerCount = 0;
  Offset? _lastPointerLocal;
  bool _touchDragClaimed = false;
  final Map<int, Offset> _touchPositions = {};
  List<int> _pinchPointers = const [];
  double _pinchStartDistance = 1;
  Offset _pinchStartFocal = Offset.zero;

  /// Axis gutters reserved by `_titles`. The focal fraction has to be taken
  /// against the inner plot rect, not the whole widget.
  static const _insets = (left: 50.0, right: 0.0, top: 0.0, bottom: 30.0);

  /// Column widths for the monospace tooltip rows, as on the profile chart.
  static const _tooltipLabelWidth = 16;
  static const _tooltipValueWidth = 12;

  static double _x(DateTime date) => date.millisecondsSinceEpoch.toDouble();

  double _focalX(Offset localPos, Size box) => chartFocalFraction(
    localPos,
    box,
    left: _insets.left,
    right: _insets.right,
    top: _insets.top,
    bottom: _insets.bottom,
  ).fx;

  double _plotWidth(Size box) =>
      (box.width - _insets.left - _insets.right).clamp(1.0, double.infinity);

  void _zoomAt(Offset localPosition, double zoomDelta, Size box) {
    if (zoomDelta == 0) return;
    setState(() {
      _activePointerKind = PointerDeviceKind.trackpad;
      _viewport = _viewport.zoomedAt(
        _focalX(localPosition, box),
        0,
        math.pow(2, zoomDelta).toDouble(),
      );
    });
  }

  void _beginPinch() {
    _pinchPointers = _touchPositions.keys.take(2).toList(growable: false);
    final p0 = _touchPositions[_pinchPointers[0]]!;
    final p1 = _touchPositions[_pinchPointers[1]]!;
    _pinchStartDistance = (p0 - p1).distance.clamp(1.0, double.infinity);
    _pinchStartFocal = (p0 + p1) / 2;
    _gestureStartViewport = _viewport;
  }

  void _updatePinch(Size box) {
    if (_pinchPointers.length < 2) return;
    final p0 = _touchPositions[_pinchPointers[0]];
    final p1 = _touchPositions[_pinchPointers[1]];
    if (p0 == null || p1 == null) return;
    setState(() {
      final scale =
          (p0 - p1).distance.clamp(1.0, double.infinity) / _pinchStartDistance;
      var vp = _gestureStartViewport.zoomedAt(
        _focalX(_pinchStartFocal, box),
        0,
        scale,
      );
      final panPx = (p0 + p1) / 2 - _pinchStartFocal;
      vp = vp.pannedBy(-panPx.dx / _plotWidth(box) / vp.zoom, 0);
      _viewport = vp;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return _EmptyChart(height: widget.height);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, widget.height);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _interactiveChart(context, box),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ChartZoomControls(
                keyPrefix: widget.chartId == null
                    ? null
                    : 'trend-${widget.chartId}',
                zoomLevel: _viewport.zoom,
                minZoom: ChartViewport.minZoom,
                maxZoom: ChartViewport.maxZoom,
                // No cursor to anchor on, so the buttons zoom about the middle
                // of the visible window.
                onZoomIn: () =>
                    setState(() => _viewport = _viewport.zoomedAt(0.5, 0, 1.5)),
                onZoomOut: () => setState(
                  () => _viewport = _viewport.zoomedAt(0.5, 0, 1 / 1.5),
                ),
                onResetZoom: () =>
                    setState(() => _viewport = ChartViewport.reset),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _interactiveChart(BuildContext context, Size box) {
    return RawGestureDetector(
      gestures: {
        TrackpadZoomGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TrackpadZoomGestureRecognizer>(
              () => TrackpadZoomGestureRecognizer(debugOwner: this),
              (recognizer) =>
                  recognizer.onZoom = (pos, delta) => _zoomAt(pos, delta, box),
            ),
      },
      child: Listener(
        onPointerDown: (event) {
          _activePointerCount++;
          _activePointerKind = event.kind;
          _lastPointerLocal = event.localPosition;
          if (event.kind == PointerDeviceKind.touch) {
            _touchPositions[event.pointer] = event.localPosition;
            if (_touchPositions.length == 2) _beginPinch();
          }
        },
        onPointerMove: (event) {
          final prev = _lastPointerLocal;
          _lastPointerLocal = event.localPosition;
          if (event.kind == PointerDeviceKind.touch) {
            _touchPositions[event.pointer] = event.localPosition;
          }
          if (prev == null) return;
          final intent = chartDragIntent(
            kind: _activePointerKind,
            pointerCount: _activePointerCount,
            isZoomed: _viewport.isZoomed,
          );
          if (intent == ChartDragIntent.zoomPan &&
              _activePointerKind == PointerDeviceKind.touch) {
            _updatePinch(box);
            return;
          }
          if (intent != ChartDragIntent.pan) return;
          // A touch drag only pans once the claim recognizer has won the
          // arena, so a scrub is never fought by a pan.
          if (_activePointerKind == PointerDeviceKind.touch &&
              !_touchDragClaimed) {
            return;
          }
          setState(() {
            final d = event.localPosition - prev;
            _viewport = _viewport.pannedBy(
              -d.dx / _plotWidth(box) / _viewport.zoom,
              0,
            );
          });
        },
        onPointerUp: (event) {
          if (_activePointerCount > 0) _activePointerCount--;
          _lastPointerLocal = null;
          _touchPositions.remove(event.pointer);
          if (_pinchPointers.contains(event.pointer)) {
            _touchPositions.length >= 2
                ? _beginPinch()
                : _pinchPointers = const [];
          }
        },
        onPointerCancel: (event) {
          if (_activePointerCount > 0) _activePointerCount--;
          _lastPointerLocal = null;
          _touchPositions.remove(event.pointer);
          _pinchPointers = const [];
        },
        // Trackpad pan-zoom is claimed by the recognizer above so it does
        // not also scroll the enclosing page.
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          setState(() {
            _activePointerKind = PointerDeviceKind.mouse;
            final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
            _viewport = _viewport.zoomedAt(
              _focalX(event.localPosition, box),
              0,
              factor,
            );
          });
        },
        child: Stack(
          children: [
            _buildChart(context),
            Positioned.fill(
              child: RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: {
                  ChartTouchClaimRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        ChartTouchClaimRecognizer
                      >(
                        () => ChartTouchClaimRecognizer(
                          isZoomed: () => _viewport.isZoomed,
                          debugOwner: this,
                        ),
                        (recognizer) {
                          recognizer.onClaimed = () {
                            _touchDragClaimed = true;
                          };
                          recognizer.onReleased = () {
                            _touchDragClaimed = false;
                          };
                        },
                      ),
                },
              ),
            ),
          ],
        ),
      ),
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

    // The window the viewport exposes, not the whole series. Ticks are chosen
    // from the visible span so a chart zoomed into a few weeks stops being
    // labelled by year.
    final fullMin = _x(buckets.first.date);
    final fullMax = _x(buckets.last.date);
    final fullSpan = (fullMax - fullMin).clamp(1.0, double.infinity);
    final visibleMin = fullMin + _viewport.offsetX * fullSpan;
    final visibleMax = visibleMin + fullSpan * _viewport.visibleWidth;
    final dateAxis = DateAxis.forRange(
      DateTime.fromMillisecondsSinceEpoch(visibleMin.toInt(), isUtc: true),
      DateTime.fromMillisecondsSinceEpoch(visibleMax.toInt(), isUtc: true),
    );

    // The fits can run outside the bucket range, so the axis has to see them.
    // Computed once here and threaded into the axis, the legend labels and
    // the bars. Each of the three used to recompute them, so a large logbook
    // paid for the same O(n) fit three times on every rebuild, and pan/zoom
    // rebuilds on every pointer move.
    final smoothed = widget.showRollingMean
        ? rollingMean(points)
        : const <TrendDataPoint>[];
    final fit = widget.showLinearFit ? linearFit(points) : null;
    final yAxis = ChartAxis.forTrend(<double>[
      ...buckets.expand((b) => [b.min, b.max]),
      ...smoothed.map((p) => p.value),
      if (fit != null) ...[
        fit.valueAt(buckets.first.date),
        fit.valueAt(buckets.last.date),
      ],
    ]);

    final isRaw = aggregation == TrendAggregation.none;
    final bars = _bars(context, buckets, color, isRaw, smoothed, fit);
    final seriesLabels = _seriesLabels(context, isRaw, smoothed, fit);

    return Semantics(
      label: yAxisLabel != null
          ? context.l10n.statistics_chart_trendSemanticLabelWithAxis(
              points.length,
              yAxisLabel,
            )
          : context.l10n.statistics_chart_trendSemanticLabel(points.length),
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
      TrendAggregation.none => l10n.statistics_trend_aggregation_perDive,
      TrendAggregation.weekly => l10n.statistics_trend_aggregation_weekly,
      TrendAggregation.monthly => l10n.statistics_trend_aggregation_monthly,
    };
    return <String>[
      mode,
      if (!isRaw) ...[
        l10n.statistics_trend_tooltip_lowest,
        l10n.statistics_trend_tooltip_highest,
      ],
      if (smoothed.isNotEmpty) l10n.statistics_trend_legend_rollingAverage,
      if (fit != null) l10n.statistics_trend_legend_rate,
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
  ) {
    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: buckets
            .map((b) => FlSpot(_x(b.date), b.mean))
            .toList(growable: false),
        isCurved: false,
        color: color,
        // Raw mode draws dots only: a stroke between two dives eight months
        // apart would assert something happened in between.
        barWidth: isRaw ? 0 : 2,
        isStrokeCapRound: true,
        // Dotted in both modes. An aggregated series drawn as a bare line
        // hides where the buckets actually are, leaving hovering as the only
        // way to find one.
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: isRaw ? 2.2 : 3,
            color: color.withValues(alpha: isRaw ? 0.7 : 1),
            strokeWidth: 0,
          ),
        ),
      ),
    ];

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

    if (fit != null) {
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

    return bars;
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
        if (!identical(barData, dataBar)) {
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
        final spot = response?.lineBarSpots?.firstOrNull;
        if (spot == null || spot.barIndex != 0) return;
        if (spot.spotIndex < 0 || spot.spotIndex >= _drawnBuckets.length) {
          return;
        }
        // Only a bucket standing for exactly one dive can be opened; an
        // aggregated bucket has no single dive behind it.
        final diveId = _drawnBuckets[spot.spotIndex].diveId;
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
                  DateFormat.yMMMd().format(date),
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
        axisNameSize: widget.yAxisLabel != null ? 20 : 0,
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
              context.l10n.statistics_chart_noTrendData,
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
