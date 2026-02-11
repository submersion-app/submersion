import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsGasPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsGasPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      appBar: AppBar(title: Text(context.l10n.statistics_gas_appBar_title)),
      body: content,
    );
  }

  Widget _buildSacTrendSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final sacTrendAsync = ref.watch(sacTrendProvider);
    final sacUnit = ref.watch(sacUnitProvider);

    // Determine unit symbol based on SAC calculation method
    final unitSymbol = sacUnit == SacUnit.litersPerMin
        ? '${units.volumeSymbol}/min'
        : '${units.pressureSymbol}/min';

    return StatSectionCard(
      title: context.l10n.statistics_gas_sacTrend_title,
      subtitle: context.l10n.statistics_gas_sacTrend_subtitle,
      child: sacTrendAsync.when(
        data: (data) => TrendLineChart(
          data: data,
          lineColor: Colors.blue,
          valueFormatter: (value) => '${value.toStringAsFixed(1)} $unitSymbol',
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_gas_sacTrend_error,
        ),
      ),
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
    final sacUnit = ref.watch(sacUnitProvider);

    // Determine unit symbol based on SAC calculation method
    final unitSymbol = sacUnit == SacUnit.litersPerMin
        ? '${units.volumeSymbol}/min'
        : '${units.pressureSymbol}/min';

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
              icon: Icons.propane_tank,
              message: context.l10n.statistics_gas_sacByRole_empty,
            );
          }

          return Column(
            children: data.entries.map((entry) {
              final role = entry.key;
              final sac = entry.value;
              final isFirst = entry.key == data.keys.first;
              final displayName = getRoleDisplayName(role);
              final sacValue = '${sac.toStringAsFixed(1)} $unitSymbol';

              return Semantics(
                label: statLabel(name: displayName, value: sacValue),
                child: Padding(
                  padding: EdgeInsets.only(top: isFirst ? 0 : 8),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.propane_tank,
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
    final sacUnit = ref.watch(sacUnitProvider);

    // Determine unit symbol based on SAC calculation method
    final unitSymbol = sacUnit == SacUnit.litersPerMin
        ? '${units.volumeSymbol}/min'
        : '${units.pressureSymbol}/min';

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

          return Column(
            children: [
              if (records.best != null)
                ValueRankingCard(
                  title: context.l10n.statistics_gas_sacRecords_best,
                  value:
                      '${records.best!.value?.toStringAsFixed(1)} $unitSymbol',
                  subtitle: records.best!.subtitle,
                  icon: Icons.emoji_events,
                  iconColor: Colors.green,
                  onTap: () => context.push('/dives/${records.best!.id}'),
                ),
              if (records.best != null && records.worst != null)
                const SizedBox(height: 8),
              if (records.worst != null)
                ValueRankingCard(
                  title: context.l10n.statistics_gas_sacRecords_highest,
                  value:
                      '${records.worst!.value?.toStringAsFixed(1)} $unitSymbol',
                  subtitle: records.worst!.subtitle,
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
