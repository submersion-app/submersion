import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Net-buoyancy-versus-time line chart. Buoyant (positive) fill above the
/// zero line, heavy (negative) fill below it; tapping a point reveals the
/// term breakdown at that moment.
class BuoyancyChart extends StatelessWidget {
  final BuoyancyTwinResult result;
  final UnitFormatter units;
  final double height;

  const BuoyancyChart({
    super.key,
    required this.result,
    required this.units,
    this.height = 180,
  });

  /// True when [s] can be plotted: both its net buoyancy and the unit-converted
  /// y value are finite. A NaN reaching fl_chart is a known crash source.
  static bool _isPlottable(TwinSample s, UnitFormatter units) =>
      s.netKg.isFinite && units.convertWeight(s.netKg).isFinite;

  /// The samples that survive the finite-value filter, in profile order. Kept
  /// in lockstep with [spotsFor] (both derive from this filter), because
  /// fl_chart reports a touched point by its index into the plotted-spot list.
  /// The tooltip must therefore resolve that index against these filtered
  /// samples -- not the raw `result.samples`, which is longer whenever a
  /// non-finite sample was dropped, which would otherwise mis-map the tooltip.
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

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => touched.map((spot) {
                final sample = plotted[spot.spotIndex];
                final staticLead =
                    sample.netKg - sample.suitKg - sample.tanksKg;
                return LineTooltipItem(
                  '${units.formatDepth(sample.depthM)}  '
                  '${_min(sample.timestamp)}\n'
                  '${context.l10n.buoyancy_chartNet}: '
                  '${units.formatWeight(sample.netKg)}\n'
                  '${context.l10n.buoyancy_suitTerm}: '
                  '${units.formatWeight(sample.suitKg)}   '
                  '${context.l10n.diveDetailSection_tanks_name}: '
                  '${units.formatWeight(sample.tanksKg)}   '
                  '${context.l10n.buoyancy_chartRig}: '
                  '${units.formatWeight(staticLead)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 11,
                  ),
                );
              }).toList(),
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
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          extraLinesData: ExtraLinesData(
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
              dotData: const FlDotData(show: false),
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
      ),
    );
  }

  String _min(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }
}
