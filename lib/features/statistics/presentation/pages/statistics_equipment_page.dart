import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/ranking_list.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_action.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class StatisticsEquipmentPage extends ConsumerWidget {
  final bool embedded;

  const StatisticsEquipmentPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMostUsedGearSection(context, ref),
          const SizedBox(height: 16),
          _buildWeightTrendSection(context, ref, units),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_equipment_appBar_title),
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

  Widget _buildMostUsedGearSection(BuildContext context, WidgetRef ref) {
    final gearAsync = ref.watch(mostUsedGearProvider);

    return StatSectionCard(
      title: context.l10n.statistics_equipment_mostUsedGear_title,
      subtitle: context.l10n.statistics_equipment_mostUsedGear_subtitle,
      child: gearAsync.when(
        data: (data) => RankingList(
          items: data,
          countLabel: context.l10n.statistics_ranking_countLabel_dives,
          maxItems: 10,
          onItemTap: (item) => context.push('/equipment/${item.id}'),
        ),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: context.l10n.statistics_equipment_mostUsedGear_error,
        ),
      ),
    );
  }

  Widget _buildWeightTrendSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    return TrendChartSection(
      chartId: TrendChartIds.weight,
      onDiveSelected: (diveId) => context.push('/dives/$diveId'),
      title: context.l10n.statistics_equipment_weightTrend_title,
      subtitle: context.l10n.statistics_equipment_weightTrend_subtitle,
      pointsAsync: ref.watch(weightTrendProvider),
      errorMessage: context.l10n.statistics_equipment_weightTrend_error,
      lineColor: Colors.purple,
      valueFormatter: (value) => units.formatWeight(value),
      rateFormatter: (value) => units.formatWeight(value),
    );
  }
}
