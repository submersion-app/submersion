import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

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
                range: settings.range,
                onRangeChanged: (range) =>
                    _update(ref, settings.copyWith(range: range)),
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
                range: settings.range,
                onRangePresetSelected: (preset) =>
                    preset == TrendRangePreset.custom
                    ? _pickCustomRange(context, ref, points)
                    : _update(
                        ref,
                        settings.copyWith(range: TrendRange.preset(preset)),
                      ),
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

  /// Opens a date-range picker over the data's days and stores the pick as
  /// a custom range, from the start of the first day to the end of the last.
  Future<void> _pickCustomRange(
    BuildContext context,
    WidgetRef ref,
    List<TrendDataPoint> points,
  ) async {
    if (points.isEmpty) return;
    var first = points.first.date;
    var last = first;
    for (final p in points) {
      if (p.date.isBefore(first)) first = p.date;
      if (p.date.isAfter(last)) last = p.date;
    }
    final firstDay = DateTime(first.year, first.month, first.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    final current = ref.read(trendChartSettingsProvider(chartId)).range;
    DateTime clampDay(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      return day.isBefore(firstDay)
          ? firstDay
          : day.isAfter(lastDay)
          ? lastDay
          : day;
    }

    final initial = current.preset == TrendRangePreset.custom
        ? DateTimeRange(
            start: clampDay(current.start!),
            end: clampDay(current.end!),
          )
        : DateTimeRange(start: firstDay, end: lastDay);
    // The shared wrapper, so typed dates follow the diver's date format.
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: firstDay,
      lastDate: lastDay,
      initialDateRange: initial,
      dateFormat: ref.read(dateFormatProvider),
    );
    // The section can be disposed while the dialog is open (the Insights
    // detail pane switched category); its ref is unusable then.
    if (picked == null || !context.mounted) return;
    final latest = ref.read(trendChartSettingsProvider(chartId));
    _update(
      ref,
      latest.copyWith(
        range: TrendRange.custom(
          DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
          DateTime.utc(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        ),
      ),
    );
  }

  void _update(WidgetRef ref, TrendChartSettings next) {
    ref.read(trendChartSettingsProvider(chartId).notifier).state = next;
  }
}
