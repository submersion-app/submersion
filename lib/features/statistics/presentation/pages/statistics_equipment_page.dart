import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/ranking_list.dart';
import '../widgets/stat_charts.dart';
import '../widgets/stat_section_card.dart';

class StatisticsEquipmentPage extends ConsumerWidget {
  const StatisticsEquipmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMostUsedGearSection(context, ref),
            const SizedBox(height: 16),
            _buildWeightTrendSection(context, ref, units),
          ],
        ),
      ),
    );
  }

  Widget _buildMostUsedGearSection(BuildContext context, WidgetRef ref) {
    final gearAsync = ref.watch(mostUsedGearProvider);

    return StatSectionCard(
      title: 'Most Used Gear',
      subtitle: 'Equipment by dive count',
      child: gearAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: 'dives',
          maxItems: 10,
          onItemTap: (item) => context.push('/equipment/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load gear data',
        ),
      ),
    );
  }

  Widget _buildWeightTrendSection(BuildContext context, WidgetRef ref, UnitFormatter units) {
    final weightTrendAsync = ref.watch(weightTrendProvider);

    return StatSectionCard(
      title: 'Weight Trend',
      subtitle: 'Average weight over time',
      child: weightTrendAsync.when(
        data: (data) => TrendLineChart(
          data: data,
          lineColor: Colors.purple,
          valueFormatter: (value) => units.formatWeight(value),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const StatEmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load weight trend',
        ),
      ),
    );
  }
}
