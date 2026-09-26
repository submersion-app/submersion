import 'package:flutter/material.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/domain/water_temp_band_metrics.dart';
import 'package:submersion/features/insights/presentation/formatters/water_temp_band_label.dart';
import 'package:submersion/features/insights/presentation/providers/insights_gas_lane_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Average consumption and bottom time per water-temperature band (issue
/// #1873), one row per band under the band chart.
///
/// Rows are laid out with shared flex weights rather than a [Table] so each
/// can be read to a screen reader as one sentence. When no dive in a band has
/// a value, its average shows "--" rather than 0. Every average carries the
/// number of dives it is based on, since SAC needs tank data that not every
/// dive has.
class WaterTempBandMetricsTable extends ConsumerWidget {
  const WaterTempBandMetricsTable({super.key, required this.bands});

  final List<WaterTempBandMetrics> bands;

  static const _bandFlex = 5;
  static const _divesFlex = 3;
  static const _averageFlex = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final isRmv = ref.watch(insightsGasLaneProvider) == GasConsumptionLane.rmv;
    String formatConsumption(double v) =>
        isRmv ? units.formatRmv(v) : units.formatSac(v);
    String formatMinutes(double v) =>
        l10n.surfaceInterval_format_minutes(v.toStringAsFixed(0));

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Each row's sentence names its columns, so the header is visual only.
        ExcludeSemantics(
          child: _row(
            band: Text(
              l10n.insights_conditions_waterTempBands_table_band,
              style: headerStyle,
            ),
            dives: Text(
              l10n.insights_conditions_waterTempBands_table_dives,
              style: headerStyle,
              textAlign: TextAlign.end,
            ),
            consumption: Text(
              isRmv
                  ? l10n.insights_conditions_waterTempBands_table_avgRmv
                  : l10n.insights_conditions_waterTempBands_table_avgSac,
              style: headerStyle,
              textAlign: TextAlign.end,
            ),
            bottomTime: Text(
              l10n.insights_conditions_waterTempBands_table_avgBottomTime,
              style: headerStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ),
        const Divider(height: 12),
        for (final band in bands)
          _bandRow(
            context,
            band: band,
            label:
                '${waterTempBandLabel(lower: band.lower, upper: band.upper)}'
                '${units.temperatureSymbol}',
            laneName: isRmv ? l10n.gasConsumption_rmv : l10n.gasConsumption_sac,
            consumption: band.avgSac == null
                ? null
                : formatConsumption(band.avgSac!),
            bottomTime: band.avgBottomMinutes == null
                ? null
                : formatMinutes(band.avgBottomMinutes!),
          ),
      ],
    );
  }

  Widget _bandRow(
    BuildContext context, {
    required WaterTempBandMetrics band,
    required String label,
    required String laneName,
    required String? consumption,
    required String? bottomTime,
  }) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    String spoken(String? value, int dives) => value == null
        ? l10n.insights_conditions_waterTempBands_table_noData
        : l10n.insights_conditions_waterTempBands_table_averageOver(
            value,
            l10n.insights_summary_tagUsage_diveCount(dives),
          );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.insights_conditions_waterTempBands_table_rowSemanticLabel(
        label,
        l10n.insights_summary_tagUsage_diveCount(band.diveCount),
        laneName,
        spoken(consumption, band.sacDiveCount),
        spoken(bottomTime, band.bottomTimeDiveCount),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _row(
          band: Text(label, style: textTheme.bodyMedium),
          dives: Text(
            '${band.diveCount}',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
          consumption: _AverageCell(
            value: consumption,
            diveCount: band.sacDiveCount,
            l10n: l10n,
          ),
          bottomTime: _AverageCell(
            value: bottomTime,
            diveCount: band.bottomTimeDiveCount,
            l10n: l10n,
          ),
        ),
      ),
    );
  }

  Widget _row({
    required Widget band,
    required Widget dives,
    required Widget consumption,
    required Widget bottomTime,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: _bandFlex, child: band),
        Expanded(flex: _divesFlex, child: dives),
        const SizedBox(width: 8),
        Expanded(flex: _averageFlex, child: consumption),
        const SizedBox(width: 8),
        Expanded(flex: _averageFlex, child: bottomTime),
      ],
    );
  }
}

/// One average and, under it, how many dives it is based on; "--" when no
/// dive in the band has the value.
class _AverageCell extends StatelessWidget {
  const _AverageCell({
    required this.value,
    required this.diveCount,
    required this.l10n,
  });

  final String? value;
  final int diveCount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final value = this.value;
    if (value == null) {
      return Text(
        '--',
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        textAlign: TextAlign.end,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.end,
        ),
        Text(
          l10n.insights_summary_tagUsage_diveCount(diveCount),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
