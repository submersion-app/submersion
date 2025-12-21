import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/ranking_list.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

class StatisticsGasPage extends ConsumerWidget {
  const StatisticsGasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Consumption'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSacTrendSection(context, ref, units),
            const SizedBox(height: 16),
            _buildGasMixSection(context, ref),
            const SizedBox(height: 16),
            _buildSacRecordsSection(context, ref, units),
          ],
        ),
      ),
    );
  }

  Widget _buildSacTrendSection(BuildContext context, WidgetRef ref, UnitFormatter units) {
    final sacTrendAsync = ref.watch(sacTrendProvider);

    return StatSectionCard(
      title: 'SAC Rate Trend',
      subtitle: 'Monthly average over 5 years',
      child: sacTrendAsync.when(
        data: (data) => TrendLineChart(
          data: data,
          lineColor: Colors.blue,
          valueFormatter: (value) => '${value.toStringAsFixed(1)} ${units.volumeSymbol}/min',
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
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
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load gas mix data',
        ),
      ),
    );
  }

  Widget _buildSacRecordsSection(BuildContext context, WidgetRef ref, UnitFormatter units) {
    final sacRecordsAsync = ref.watch(sacRecordsProvider);

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
                  value: '${records.best!.value?.toStringAsFixed(1)} ${units.volumeSymbol}/min',
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
                  value: '${records.worst!.value?.toStringAsFixed(1)} ${units.volumeSymbol}/min',
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
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load SAC records',
        ),
      ),
    );
  }
}
