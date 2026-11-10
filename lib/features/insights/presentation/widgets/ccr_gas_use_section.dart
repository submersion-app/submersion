import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/ccr_gas_use_trend.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/info/insights_card_info.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/rate_average_tile.dart';
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
  // Not orange: the rolling mean is amber in both themes.
  static const _diluentColor = Colors.green;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`, not `valueOrNull`: a filter change reloads this provider, and
    // the last trend stays up rather than the card leaving the page.
    final trend = ref.watch(ccrGasUseTrendProvider).value;
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
        infoSummary: l10n.info_insights_ccrUse_summary,
        infoTerms: ccrGasUseTerms(showsDiluent: trend.diluent.isNotEmpty),
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
        RateAverageTile(
          color: _o2Color,
          value: format(average),
          label: l10n.insights_gas_ccrUse_o2Average,
        ),
      if (trend.diluentAverage case final average?)
        RateAverageTile(
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
