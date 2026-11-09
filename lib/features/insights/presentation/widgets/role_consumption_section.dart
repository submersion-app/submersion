import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_gas_lane_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/rate_average_tile.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Gas page's consumption by cylinder role card (issue #771): one line
/// per role group, each point a dive's rate for that role over the time it
/// was breathed, with each group's average above the chart.
class RoleConsumptionSection extends ConsumerWidget {
  const RoleConsumptionSection({super.key});

  /// At least 20 apart (CIEDE2000) from each other and from the rolling
  /// mean's amber in both themes: indigo beside purple, or pink beside red,
  /// read as one line at chart dot size. Lighter on a dark surface, where the
  /// full shades fall under 3:1 contrast.
  static Map<ConsumptionRoleGroup, Color> _colorsFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return {
      ConsumptionRoleGroup.bottomGas: dark
          ? Colors.indigo.shade300
          : Colors.indigo,
      ConsumptionRoleGroup.stage: dark
          ? Colors.teal.shade300
          : Colors.teal.shade700,
      ConsumptionRoleGroup.deco: dark
          ? Colors.lightGreen.shade300
          : Colors.lightGreen.shade700,
      ConsumptionRoleGroup.pony: dark ? Colors.brown.shade300 : Colors.brown,
      ConsumptionRoleGroup.bailout: dark ? Colors.pink.shade300 : Colors.pink,
    };
  }

  static String _label(AppLocalizations l10n, ConsumptionRoleGroup group) =>
      switch (group) {
        ConsumptionRoleGroup.bottomGas => l10n.insights_gas_roleGroup_bottomGas,
        ConsumptionRoleGroup.stage => l10n.insights_gas_tankRole_stage,
        ConsumptionRoleGroup.deco => l10n.insights_gas_tankRole_deco,
        ConsumptionRoleGroup.pony => l10n.insights_gas_tankRole_pony,
        ConsumptionRoleGroup.bailout => l10n.insights_gas_tankRole_bailout,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final lane = ref.watch(insightsGasLaneProvider);
    final trendAsync = ref.watch(roleConsumptionTrendProvider);

    final isRmv = lane == GasConsumptionLane.rmv;
    String format(double v) => isRmv ? units.formatRmv(v) : units.formatSac(v);
    double convert(double v) =>
        isRmv ? units.convertRmv(v) : units.convertSac(v);
    final decimals = isRmv ? units.rmvDecimals : units.sacDecimals;

    TrendChartSection section({
      required AsyncValue<List<TrendDataPoint>> points,
      Color color = Colors.indigo,
      Widget? header,
      String? pointLabel,
      List<TrendSeries> secondary = const [],
      Widget? footer,
    }) => TrendChartSection(
      chartId: TrendChartIds.roleConsumption,
      onDiveSelected: (diveId) => context.push('/dives/$diveId'),
      title: l10n.insights_gas_roleUse_title,
      subtitle: l10n.insights_gas_roleUse_subtitle,
      header: header,
      pointsAsync: points,
      pointLabel: pointLabel,
      secondarySeries: secondary,
      footer: footer,
      errorMessage: l10n.insights_gas_roleUse_error,
      lineColor: color,
      yAxisLabel: isRmv ? units.rmvSymbol : units.sacSymbol,
      valueFormatter: format,
      yAxisFormatter: (value) => convert(value).toStringAsFixed(decimals),
      rateFormatter: format,
    );

    // `.value`, not `valueOrNull`: a filter change reloads this provider, and
    // the last trend stays up rather than the chart blinking out.
    final trend = trendAsync.value;
    if (trend == null) {
      return section(
        points: trendAsync.hasError
            ? AsyncError(trendAsync.error!, trendAsync.stackTrace!)
            : const AsyncLoading(),
      );
    }

    final series = trend.forLane(lane);
    final groups = [
      for (final group in ConsumptionRoleGroup.values)
        if (series[group]?.isNotEmpty ?? false) group,
    ];
    final theme = Theme.of(context);
    // The diver this note is for, one who logs deco dives without switches,
    // may have every dive left out, so the empty card says so too.
    final leftOutNote = trend.leftOutDives > 0
        ? Text(
            l10n.insights_gas_roleUse_leftOut(trend.leftOutDives),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        : null;
    if (groups.isEmpty) {
      return StatSectionCard(
        title: l10n.insights_gas_roleUse_title,
        subtitle: l10n.insights_gas_roleUse_subtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatEmptyState(
              icon: MdiIcons.divingScubaTank,
              message: l10n.insights_gas_roleUse_empty,
            ),
            ?leftOutNote,
          ],
        ),
      );
    }
    final colors = _colorsFor(theme.brightness);

    // The fit, the rolling mean and the range picker read the primary line.
    final primary = groups.contains(ConsumptionRoleGroup.bottomGas)
        ? ConsumptionRoleGroup.bottomGas
        : groups.first;
    return section(
      points: AsyncData(series[primary]!),
      color: colors[primary]!,
      pointLabel: _label(l10n, primary),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        // A Wrap, not a Row: five tiles do not fit a phone.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth >= 480
                ? (constraints.maxWidth - 16) / 3
                : (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in groups)
                  SizedBox(
                    width: tileWidth,
                    child: RateAverageTile(
                      color: colors[group]!,
                      value: format(trend.average(lane, group)!),
                      label: _label(l10n, group),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      secondary: [
        for (final group in groups)
          if (group != primary)
            TrendSeries(
              label: _label(l10n, group),
              points: series[group]!,
              color: colors[group]!,
            ),
      ],
      footer: leftOutNote,
    );
  }
}
