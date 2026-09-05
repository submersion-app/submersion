import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_control_strip.dart';

/// One per-dive trend chart, its card and its controls.
///
/// Four pages need exactly this combination, so it lives in one widget: the
/// pages stay short and a layout fix lands once rather than four times.
class TrendChartSection extends ConsumerWidget {
  const TrendChartSection({
    super.key,
    required this.chartId,
    required this.title,
    required this.subtitle,
    required this.pointsAsync,
    required this.errorMessage,
    required this.lineColor,
    this.yAxisLabel,
    this.valueFormatter,
    this.yAxisFormatter,
    this.rateFormatter,
    this.onDiveSelected,
  });

  /// Key into [trendChartSettingsProvider]. Use a [TrendChartIds] constant.
  final String chartId;

  final String title;
  final String subtitle;
  final AsyncValue<List<TrendDataPoint>> pointsAsync;
  final String errorMessage;
  final Color lineColor;
  final String? yAxisLabel;
  final String Function(double)? valueFormatter;
  final String Function(double)? yAxisFormatter;

  /// Formats the fitted per-year rate with its unit symbol. Null hides the
  /// numeric rate and leaves the legend entry as a plain toggle.
  final String Function(double)? rateFormatter;

  /// Opens the dive behind a tapped point. Only fires in per-dive mode.
  final void Function(String diveId)? onDiveSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(trendChartSettingsProvider(chartId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // The three layers must be told apart at a glance, so the overlays do NOT
    // reuse the chart's identity colour. Drawing the rolling mean in the same
    // blue as the series it smooths made the two indistinguishable and left
    // the legend swatch identifying nothing.
    final rollingColor = isDark ? Colors.amber.shade300 : Colors.amber.shade800;
    final rateColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return StatSectionCard(
      title: title,
      subtitle: subtitle,
      child: pointsAsync.when(
        data: (points) {
          final fit = settings.showLinearFit ? linearFit(points) : null;
          final rate = (fit != null && rateFormatter != null)
              ? rateFormatter!(fit.perYear)
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiveTrendChart(
                chartId: chartId,
                points: points,
                dateFormat: ref.watch(dateFormatProvider),
                onDiveSelected: onDiveSelected,
                aggregation: settings.aggregation,
                showRollingMean: settings.showRollingMean,
                showLinearFit: settings.showLinearFit,
                pointColor: lineColor,
                rollingColor: rollingColor,
                rateColor: rateColor,
                yAxisLabel: yAxisLabel,
                valueFormatter: valueFormatter,
                yAxisFormatter: yAxisFormatter,
              ),
              TrendControlStrip(
                chartId: chartId,
                seriesColor: lineColor,
                aggregation: settings.aggregation,
                onAggregationChanged: (mode) =>
                    _update(ref, settings.copyWith(aggregation: mode)),
                showRollingMean: settings.showRollingMean,
                onToggleRollingMean: () => _update(
                  ref,
                  settings.copyWith(showRollingMean: !settings.showRollingMean),
                ),
                showLinearFit: settings.showLinearFit,
                onToggleLinearFit: () => _update(
                  ref,
                  settings.copyWith(showLinearFit: !settings.showLinearFit),
                ),
                rollingColor: rollingColor,
                rateColor: rateColor,
                rateLabel: rate,
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) =>
            StatEmptyState(icon: Icons.error_outline, message: errorMessage),
      ),
    );
  }

  void _update(WidgetRef ref, TrendChartSettings next) {
    ref.read(trendChartSettingsProvider(chartId).notifier).state = next;
  }
}
