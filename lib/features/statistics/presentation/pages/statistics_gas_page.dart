import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/units.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/ranking_list.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

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
      appBar: AppBar(title: const Text('Air Consumption')),
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
      title: 'SAC Rate Trend',
      subtitle: 'Monthly average over 5 years',
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
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load SAC trend',
        ),
      ),
    );
  }

  Widget _buildGasMixSection(BuildContext context, WidgetRef ref) {
    final gasMixAsync = ref.watch(gasMixDistributionProvider);

    return StatSectionCard(
      title: 'Gas Mix Distribution',
      subtitle: 'Dives by gas type',
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
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load gas mix data',
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
        'backGas' => 'Back Gas',
        'stage' => 'Stage',
        'deco' => 'Deco',
        'bailout' => 'Bailout',
        'sidemountLeft' => 'Sidemount L',
        'sidemountRight' => 'Sidemount R',
        'pony' => 'Pony',
        'diluent' => 'Diluent',
        'oxygenSupply' => 'O₂ Supply',
        _ => role,
      };
    }

    return StatSectionCard(
      title: 'SAC by Tank Role',
      subtitle: 'Average consumption by tank type',
      child: sacByRoleAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const StatEmptyState(
              icon: Icons.propane_tank,
              message: 'No multi-tank data available',
            );
          }

          return Column(
            children: data.entries.map((entry) {
              final role = entry.key;
              final sac = entry.value;
              final isFirst = entry.key == data.keys.first;

              return Padding(
                padding: EdgeInsets.only(top: isFirst ? 0 : 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.propane_tank,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        getRoleDisplayName(role),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${sac.toStringAsFixed(1)} $unitSymbol',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load SAC by role',
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
      title: 'SAC Rate Records',
      subtitle: 'Best and worst air consumption',
      child: sacRecordsAsync.when(
        data: (records) {
          if (records.best == null && records.worst == null) {
            return const StatEmptyState(
              icon: Icons.air,
              message: 'No SAC data available yet',
            );
          }

          return Column(
            children: [
              if (records.best != null)
                ValueRankingCard(
                  title: 'Best SAC Rate',
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
                  title: 'Highest SAC Rate',
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
        error: (_, _) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load SAC records',
        ),
      ),
    );
  }
}
