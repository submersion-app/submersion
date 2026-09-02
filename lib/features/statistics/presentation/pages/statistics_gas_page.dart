import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_gas_lane_provider.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_action.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsGasPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsGasPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final display = settings.gasConsumptionDisplay;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (display == GasConsumptionDisplay.both) ...[
            _buildLaneSelector(context, ref),
            const SizedBox(height: 16),
          ],
          _buildSacTrendSection(context, ref, units),
          const SizedBox(height: 16),
          _buildGasMixSection(context, ref),
          const SizedBox(height: 16),
          _buildSacByRoleSection(context, ref, units),
          const SizedBox(height: 16),
          _buildSacRecordsSection(context, ref, units),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_gas_appBar_title),
        actions: const [StatisticsFilterAction()],
      ),
      // Expanded is required: content is a SingleChildScrollView, and a
      // Column would otherwise hand it unbounded height.
      body: Column(
        children: [
          const StatisticsFilterBar(),
          Expanded(child: content),
        ],
      ),
    );
  }

  /// SAC | RMV for the whole page, shown only when the preference displays
  /// both lanes. Three sections with two lanes each would be six charts.
  Widget _buildLaneSelector(BuildContext context, WidgetRef ref) {
    final lane = ref.watch(statisticsGasLaneProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<GasConsumptionLane>(
        segments: [
          ButtonSegment(
            value: GasConsumptionLane.sac,
            label: Text(context.l10n.gasConsumption_sac),
          ),
          ButtonSegment(
            value: GasConsumptionLane.rmv,
            label: Text(context.l10n.gasConsumption_rmv),
          ),
        ],
        selected: {lane},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            ref.read(statisticsGasLaneOverrideProvider.notifier).state =
                selection.first,
      ),
    );
  }

  Widget _buildSacTrendSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final lane = ref.watch(statisticsGasLaneProvider);
    final isRmv = lane == GasConsumptionLane.rmv;
    final unitSymbol = isRmv ? units.rmvSymbol : units.sacSymbol;
    String format(double v) => isRmv ? units.formatRmv(v) : units.formatSac(v);
    double convert(double v) =>
        isRmv ? units.convertRmv(v) : units.convertSac(v);
    // The axis draws the bare number, so it has to round the way the
    // tooltip's labelled value does or the two disagree (an imperial RMV
    // tick read 0.5 where its tooltip said 0.53).
    final decimals = isRmv ? units.rmvDecimals : units.sacDecimals;

    return TrendChartSection(
      chartId: TrendChartIds.sac,
      onDiveSelected: (diveId) => context.push('/dives/$diveId'),
      title: context.l10n.statistics_gas_sacTrend_title,
      subtitle: context.l10n.statistics_gas_sacTrend_subtitle,
      pointsAsync: ref.watch(sacTrendProvider),
      errorMessage: context.l10n.statistics_gas_sacTrend_error,
      lineColor: Colors.blue,
      yAxisLabel: unitSymbol,
      valueFormatter: format,
      yAxisFormatter: (value) => convert(value).toStringAsFixed(decimals),
      rateFormatter: format,
    );
  }

  Widget _buildGasMixSection(BuildContext context, WidgetRef ref) {
    final gasMixAsync = ref.watch(gasMixDistributionProvider);

    return StatSectionCard(
      title: context.l10n.statistics_gas_gasMix_title,
      subtitle: context.l10n.statistics_gas_gasMix_subtitle,
      child: gasMixAsync.when(
        data: (data) => DistributionPieChart(
          data: data,
          colors: [
            Colors.blue.shade400,
            Colors.green.shade400,
            Colors.purple.shade400,
          ],
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_gas_gasMix_error,
        ),
      ),
    );
  }

  Widget _buildSacByRoleSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final sacByRoleAsync = ref.watch(sacByTankRoleProvider);
    final lane = ref.watch(statisticsGasLaneProvider);
    final isRmv = lane == GasConsumptionLane.rmv;
    String format(double v) => isRmv ? units.formatRmv(v) : units.formatSac(v);

    // Map tank role keys to display names
    String getRoleDisplayName(String role) {
      return switch (role) {
        'backGas' => context.l10n.statistics_gas_tankRole_backGas,
        'stage' => context.l10n.statistics_gas_tankRole_stage,
        'deco' => context.l10n.statistics_gas_tankRole_deco,
        'bailout' => context.l10n.statistics_gas_tankRole_bailout,
        'sidemountLeft' => context.l10n.statistics_gas_tankRole_sidemountLeft,
        'sidemountRight' => context.l10n.statistics_gas_tankRole_sidemountRight,
        'pony' => context.l10n.statistics_gas_tankRole_pony,
        'diluent' => context.l10n.statistics_gas_tankRole_diluent,
        'oxygenSupply' => context.l10n.statistics_gas_tankRole_oxygenSupply,
        _ => role,
      };
    }

    return StatSectionCard(
      title: context.l10n.statistics_gas_sacByRole_title,
      subtitle: context.l10n.statistics_gas_sacByRole_subtitle,
      child: sacByRoleAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return StatEmptyState(
              icon: MdiIcons.divingScubaTank,
              message: context.l10n.statistics_gas_sacByRole_empty,
            );
          }

          return Column(
            children: data.entries.map((entry) {
              final role = entry.key;
              final sac = entry.value;
              final isFirst = entry.key == data.keys.first;
              final displayName = getRoleDisplayName(role);
              final sacValue = format(sac);

              return Semantics(
                label: statLabel(name: displayName, value: sacValue),
                child: Padding(
                  padding: EdgeInsets.only(top: isFirst ? 0 : 8),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          MdiIcons.divingScubaTank,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        sacValue,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_gas_sacByRole_error,
        ),
      ),
    );
  }

  Widget _buildSacRecordsSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final sacRecordsAsync = ref.watch(sacRecordsProvider);
    final lane = ref.watch(statisticsGasLaneProvider);
    final isRmv = lane == GasConsumptionLane.rmv;
    final unitSymbol = isRmv ? units.rmvSymbol : units.sacSymbol;
    String format(double v) => isRmv ? units.formatRmv(v) : units.formatSac(v);

    return StatSectionCard(
      title: context.l10n.statistics_gas_sacRecords_title,
      subtitle: context.l10n.statistics_gas_sacRecords_subtitle,
      child: sacRecordsAsync.when(
        data: (records) {
          if (records.best == null && records.worst == null) {
            return StatEmptyState(
              icon: Icons.air,
              message: context.l10n.statistics_gas_sacRecords_empty,
            );
          }

          String formatSacRecord(double? value) =>
              value == null ? '-- $unitSymbol' : format(value);

          return Column(
            children: [
              if (records.best != null)
                ValueRankingCard(
                  title: isRmv
                      ? context.l10n.statistics_gas_sacRecords_bestRmv
                      : context.l10n.statistics_gas_sacRecords_bestSac,
                  value: formatSacRecord(records.best!.value),
                  subtitle: units.formatDate(records.best!.date),
                  icon: Icons.emoji_events,
                  iconColor: Colors.green,
                  onTap: () => context.push('/dives/${records.best!.id}'),
                ),
              if (records.best != null && records.worst != null)
                const SizedBox(height: 8),
              if (records.worst != null)
                ValueRankingCard(
                  title: isRmv
                      ? context.l10n.statistics_gas_sacRecords_highestRmv
                      : context.l10n.statistics_gas_sacRecords_highestSac,
                  value: formatSacRecord(records.worst!.value),
                  subtitle: units.formatDate(records.worst!.date),
                  icon: Icons.speed,
                  iconColor: Colors.orange,
                  onTap: () => context.push('/dives/${records.worst!.id}'),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_gas_sacRecords_error,
        ),
      ),
    );
  }
}
