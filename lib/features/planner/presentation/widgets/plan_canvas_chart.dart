import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The user-authored segment whose time span covers [timeSeconds], or null
/// when the time falls in the computed ascent past the last segment.
///
/// Pure and exported for unit testing (fl_chart interaction can't be driven
/// in widget tests).
String? segmentIdAtTime(List<PlanSegment> segments, double timeSeconds) {
  final ordered = List<PlanSegment>.from(segments)
    ..sort((a, b) => a.order.compareTo(b.order));
  var elapsed = 0.0;
  for (final segment in ordered) {
    final end = elapsed + segment.durationSeconds;
    if (timeSeconds >= elapsed && timeSeconds <= end) return segment.id;
    elapsed = end;
  }
  return null;
}

/// The hero chart of the Live Profile Canvas: the planned profile with the
/// computed deco tail, a ceiling overlay, gas-switch markers, and a scrub
/// cursor with a live readout.
class PlanCanvasChart extends ConsumerWidget {
  const PlanCanvasChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(planCanvasSeriesProvider);
    final scrubTime = ref.watch(scrubTimeProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    if (series.isEmpty) {
      return _EmptyState(theme: theme);
    }

    final maxDepthDisplay = units.convertDepth(series.maxDepth);
    final maxTime = series.maxTimeSeconds / 60;

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
            child: LineChart(
              _buildChartData(
                context,
                ref,
                series,
                scrubTime,
                maxDepthDisplay,
                maxTime,
                theme,
                units,
              ),
            ),
          ),
        ),
        if (scrubTime != null)
          Positioned(
            top: 12,
            left: 12,
            child: _ScrubReadout(
              runtimeSeconds: scrubTime,
              depthMeters: series.depthAt(scrubTime),
              units: units,
            ),
          ),
      ],
    );
  }

  LineChartData _buildChartData(
    BuildContext context,
    WidgetRef ref,
    PlanCanvasSeries series,
    double? scrubTime,
    double maxDepthDisplay,
    double maxTime,
    ThemeData theme,
    UnitFormatter units,
  ) {
    FlSpot toSpot(CanvasPoint p) =>
        FlSpot(p.timeSeconds / 60, -units.convertDepth(p.depth));

    final profileSpots = series.profile.map(toSpot).toList();
    final ceilingSpots = series.ceiling.map(toSpot).toList();

    final verticalLines = <VerticalLine>[
      for (final marker in series.gasSwitches)
        VerticalLine(
          x: marker.timeSeconds / 60,
          color: theme.colorScheme.tertiary,
          strokeWidth: 1.5,
          dashArray: const [3, 3],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
            labelResolver: (_) => marker.label,
          ),
        ),
      if (scrubTime != null)
        VerticalLine(
          x: scrubTime / 60,
          color: theme.colorScheme.outline,
          strokeWidth: 1,
          dashArray: const [2, 3],
        ),
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        horizontalInterval: _calculateInterval(maxDepthDisplay),
        verticalInterval: _calculateInterval(maxTime),
        getDrawingHorizontalLine: (_) => FlLine(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (_) => FlLine(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          axisNameWidget: Text(
            context.l10n.divePlanner_label_timeAxis,
            style: theme.textTheme.labelSmall,
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: _calculateInterval(maxTime),
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                value.toStringAsFixed(0),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: Text(
            context.l10n.divePlanner_label_depthAxis(units.depthSymbol),
            style: theme.textTheme.labelSmall,
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            interval: _calculateInterval(maxDepthDisplay),
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                (-value).toStringAsFixed(0),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      extraLinesData: ExtraLinesData(verticalLines: verticalLines),
      minX: 0,
      maxX: maxTime > 0 ? maxTime * 1.05 : 10,
      minY: maxDepthDisplay > 0 ? -maxDepthDisplay * 1.1 : -10,
      maxY: 0,
      lineBarsData: [
        // Ceiling overlay (dashed, drawn under the profile line).
        if (ceilingSpots.length >= 2)
          LineChartBarData(
            spots: ceilingSpots,
            isCurved: false,
            color: theme.colorScheme.error.withValues(alpha: 0.7),
            barWidth: 1.5,
            dashArray: const [4, 4],
            dotData: const FlDotData(show: false),
          ),
        LineChartBarData(
          spots: profileSpots,
          isCurved: false,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.05),
                theme.colorScheme.primary.withValues(alpha: 0.3),
              ],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        // Own scrub line + readout; suppress the built-in tooltip/indicator.
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((_) => null).toList(),
        ),
        getTouchedSpotIndicator: (barData, indexes) => indexes
            .map(
              (_) => const TouchedSpotIndicatorData(
                FlLine(color: Colors.transparent),
                FlDotData(show: false),
              ),
            )
            .toList(),
        touchCallback: (event, response) {
          final notifier = ref.read(scrubTimeProvider.notifier);
          if (event is FlPanEndEvent ||
              event is FlTapUpEvent ||
              event is FlLongPressEnd ||
              event is FlPointerExitEvent) {
            notifier.state = null;
            return;
          }
          final spot = response?.lineBarSpots?.first;
          if (spot != null) {
            final seconds = spot.x * 60;
            notifier.state = seconds;
            if (event is FlTapUpEvent || event is FlTapDownEvent) {
              final segments = ref.read(divePlanNotifierProvider).segments;
              ref.read(selectedSegmentIdProvider.notifier).state =
                  segmentIdAtTime(segments, seconds);
            }
          }
        },
      ),
    );
  }

  double _calculateInterval(double maxValue) {
    if (maxValue <= 0) return 5;
    if (maxValue <= 10) return 2;
    if (maxValue <= 20) return 5;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    return 30;
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            context.l10n.divePlanner_message_noProfile,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.divePlanner_message_addSegmentsForProfile,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SimplePlanDialog(),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: Text(context.l10n.divePlanner_action_quickPlan),
          ),
        ],
      ),
    );
  }
}

class _ScrubReadout extends StatelessWidget {
  const _ScrubReadout({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.units,
  });

  final double runtimeSeconds;
  final double depthMeters;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = (runtimeSeconds / 60).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.95,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        context.l10n.plannerCanvas_scrub_readout(
          minutes.toString(),
          units.formatDepth(depthMeters, decimals: 0),
        ),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
