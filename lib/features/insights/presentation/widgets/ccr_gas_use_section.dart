import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/ccr_gas_use_trend.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Gas page's Rebreather gas use card: O2 and diluent averages over one
/// chart carrying both lines, per minute on the loop (issue #4082).
///
/// Most divers never dive a rebreather, so nothing at all shows, not even the
/// card's spacing, until there is a rate to draw. For the same reason it stays
/// quiet while loading and on an error rather than interrupting their page.
class CcrGasUseSection extends ConsumerWidget {
  const CcrGasUseSection({super.key});

  static const _o2Color = Colors.blue;
  static const _diluentColor = Colors.orange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(ccrGasUseTrendProvider).valueOrNull;
    if (trend == null || trend.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    // The fit, the rolling mean and the range picker read the primary series,
    // so a diver with no O2 line has diluent there.
    final diluentOnly = trend.o2.isEmpty;
    final diluentLabel = l10n.insights_gas_tankRole_diluent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TrendChartSection(
        chartId: TrendChartIds.ccrGasUse,
        onDiveSelected: (diveId) => context.push('/dives/$diveId'),
        title: l10n.insights_gas_ccrUse_title,
        subtitle: l10n.insights_gas_ccrUse_subtitle,
        header: _averages(context, trend, units.formatRmv),
        pointsAsync: AsyncData(diluentOnly ? trend.diluent : trend.o2),
        pointLabel: diluentOnly
            ? diluentLabel
            : l10n.insights_gas_ccrUse_o2Series,
        secondarySeries: [
          if (!diluentOnly && trend.diluent.isNotEmpty)
            TrendSeries(
              label: diluentLabel,
              points: trend.diluent,
              color: _diluentColor,
            ),
        ],
        // The card hides on an error, so this is never shown.
        errorMessage: l10n.insights_gas_sacTrend_error,
        lineColor: diluentOnly ? _diluentColor : _o2Color,
        yAxisLabel: units.rmvSymbol,
        valueFormatter: units.formatRmv,
        yAxisFormatter: (value) =>
            units.convertRmv(value).toStringAsFixed(units.rmvDecimals),
        rateFormatter: units.formatRmv,
      ),
    );
  }

  /// One tile per line with data. Their dots double as the chart's legend.
  Widget _averages(
    BuildContext context,
    CcrGasUseTrend trend,
    String Function(double) format,
  ) {
    final l10n = context.l10n;
    final tiles = [
      if (trend.o2Average case final average?)
        _AverageTile(
          color: _o2Color,
          value: format(average),
          label: l10n.insights_gas_ccrUse_o2Average,
        ),
      if (trend.diluentAverage case final average?)
        _AverageTile(
          color: _diluentColor,
          value: format(average),
          label: l10n.insights_gas_ccrUse_diluentAverage,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        spacing: 8,
        children: [for (final tile in tiles) Expanded(child: tile)],
      ),
    );
  }
}

class _AverageTile extends StatelessWidget {
  const _AverageTile({
    required this.color,
    required this.value,
    required this.label,
  });

  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: statLabel(name: label, value: value),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            spacing: 8,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 10),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
