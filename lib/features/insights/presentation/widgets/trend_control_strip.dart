import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/formatters/trend_range_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The control row beneath a `DiveTrendChart`: how dives are grouped, and
/// which fitted overlays are drawn.
///
/// Everything lives on one row so a card costs exactly one extra line however
/// many controls it carries. The overlay toggles double as the colour key, so
/// a diver can see what the second line is without tapping anything.
///
/// A `PopupMenuButton` rather than Material 3's `DropdownMenu`: the latter is a
/// text-field-shaped widget far too heavy for a chart footer. Same compact
/// pattern as `gps_track_date_filter_action.dart`.
class TrendControlStrip extends StatelessWidget {
  const TrendControlStrip({
    super.key,
    required this.chartId,
    required this.aggregation,
    required this.onAggregationChanged,
    required this.showRollingMean,
    required this.onToggleRollingMean,
    required this.showLinearFit,
    required this.onToggleLinearFit,
    required this.seriesColor,
    required this.rollingColor,
    required this.rateColor,
    this.rateLabel,
    this.range = TrendRange.all,
    this.onRangePresetSelected,
  });

  /// Stable id from `TrendChartIds`, used to build unique widget keys.
  final String chartId;

  final TrendAggregation aggregation;
  final ValueChanged<TrendAggregation> onAggregationChanged;

  /// Colour of the data series itself. The mode control doubles as that
  /// series' legend entry, so the row explains all three layers without
  /// naming the current mode twice.
  final Color seriesColor;
  final bool showRollingMean;
  final VoidCallback onToggleRollingMean;
  final bool showLinearFit;
  final VoidCallback onToggleLinearFit;
  final Color rollingColor;
  final Color rateColor;

  /// The fitted rate with its unit symbol, for example "+4.4 m". Null when
  /// there are too few dives to fit. Only shown while [showLinearFit] is true.
  final String? rateLabel;

  /// The chart's visible window, named on the Range menu.
  final TrendRange range;

  /// Called with the picked entry. [TrendRangePreset.custom] asks the caller
  /// to open a date picker. Null hides the menu.
  final ValueChanged<TrendRangePreset>? onRangePresetSelected;

  String _modeLabel(BuildContext context, TrendAggregation mode) {
    switch (mode) {
      case TrendAggregation.none:
        return context.l10n.insights_trend_aggregation_perDive;
      case TrendAggregation.weekly:
        return context.l10n.insights_trend_aggregation_weekly;
      case TrendAggregation.monthly:
        return context.l10n.insights_trend_aggregation_monthly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = rateLabel;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onRangePresetSelected != null)
            PopupMenuButton<TrendRangePreset>(
              key: ValueKey('trend-range-$chartId'),
              tooltip: context.l10n.insights_trend_range_tooltip,
              initialValue: range.preset,
              onSelected: onRangePresetSelected,
              itemBuilder: (context) => [
                for (final preset in TrendRangePreset.values)
                  PopupMenuItem<TrendRangePreset>(
                    key: ValueKey('trend-range-$chartId-${preset.name}'),
                    value: preset,
                    child: Text(
                      trendRangeLabel(preset, context.l10n, menuItem: true),
                    ),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    trendRangeLabel(range.preset, context.l10n),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          PopupMenuButton<TrendAggregation>(
            key: ValueKey('trend-aggregation-$chartId'),
            tooltip: context.l10n.insights_trend_aggregation_tooltip,
            initialValue: aggregation,
            onSelected: onAggregationChanged,
            itemBuilder: (context) => TrendAggregation.values
                .map(
                  (mode) => PopupMenuItem<TrendAggregation>(
                    value: mode,
                    child: Text(_modeLabel(context, mode)),
                  ),
                )
                .toList(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: ValueKey('trend-series-swatch-$chartId'),
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: seriesColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _modeLabel(context, aggregation),
                  style: theme.textTheme.bodySmall,
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
          _LegendToggle(
            toggleKey: ValueKey('trend-legend-rolling-$chartId'),
            color: rollingColor,
            label: context.l10n.insights_trend_legend_rollingAverage,
            enabled: showRollingMean,
            onTap: onToggleRollingMean,
          ),
          _LegendToggle(
            toggleKey: ValueKey('trend-legend-rate-$chartId'),
            color: rateColor,
            label: showLinearFit && rate != null
                ? context.l10n.insights_trend_rate_perYear(rate)
                : context.l10n.insights_trend_legend_rate,
            enabled: showLinearFit,
            onTap: onToggleLinearFit,
          ),
        ],
      ),
    );
  }
}

/// One tappable legend entry: a colour swatch plus a label, dimmed when its
/// overlay is off.
class _LegendToggle extends StatelessWidget {
  const _LegendToggle({
    required this.toggleKey,
    required this.color,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final Key toggleKey;
  final Color color;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: toggleKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
