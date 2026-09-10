import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/providers/equipment_condition_statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
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
          _buildExposureSection(context, ref, units),
          const SizedBox(height: 16),
          _buildFindingsSection(context, ref),
          const SizedBox(height: 16),
          _buildIssuesSection(context, ref),
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

  /// Exposure per active item in the unit the dropdown selects; the row
  /// count is the rounded total, the subtitle the exact figure.
  Widget _buildExposureSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final l10n = context.l10n;
    final unit = ref.watch(exposureRankingUnitProvider);
    final rankingAsync = ref.watch(exposureRankingProvider);
    return StatSectionCard(
      title: l10n.statistics_equipment_exposure_title,
      subtitle: l10n.statistics_equipment_exposure_subtitle,
      trailing: DropdownButton<ExposureUnit>(
        key: const ValueKey('exposure-unit'),
        value: unit,
        underline: const SizedBox.shrink(),
        items: [
          for (final u in _rankingUnits)
            DropdownMenuItem(value: u, child: Text(_unitLabel(l10n, u))),
        ],
        onChanged: (u) {
          if (u != null) {
            ref.read(exposureRankingUnitProvider.notifier).state = u;
          }
        },
      ),
      child: rankingAsync.when(
        data: (data) => data.isEmpty
            ? StatEmptyState(
                icon: Icons.waves,
                message: l10n.statistics_equipment_exposure_empty,
              )
            : RankingList(
                items: data,
                countLabel: _countLabel(l10n, unit),
                maxItems: 10,
                onItemTap: (item) => context.push('/equipment/${item.id}'),
              ),
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.statistics_equipment_exposure_empty,
        ),
      ),
    );
  }

  Widget _buildFindingsSection(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _rankingSection(
      context,
      ref.watch(findingsByRuleProvider),
      title: l10n.statistics_equipment_findings_title,
      subtitle: l10n.statistics_equipment_findings_subtitle,
      countLabel: l10n.statistics_equipment_countLabel_findings,
      empty: l10n.statistics_equipment_findings_empty,
      icon: Icons.insights_outlined,
    );
  }

  Widget _buildIssuesSection(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _rankingSection(
      context,
      ref.watch(issueTagRankingProvider),
      title: l10n.statistics_equipment_issues_title,
      subtitle: l10n.statistics_equipment_issues_subtitle,
      countLabel: l10n.statistics_equipment_countLabel_reports,
      empty: l10n.statistics_equipment_issues_empty,
      icon: Icons.report_problem_outlined,
    );
  }

  Widget _rankingSection(
    BuildContext context,
    AsyncValue<List<RankingItem>> rankingAsync, {
    required String title,
    required String subtitle,
    required String countLabel,
    required String empty,
    required IconData icon,
  }) {
    return StatSectionCard(
      title: title,
      subtitle: subtitle,
      child: rankingAsync.when(
        data: (data) => data.isEmpty
            ? StatEmptyState(icon: icon, message: empty)
            : RankingList(
                items: data,
                countLabel: countLabel,
                maxItems: 10,
                showMedals: false,
              ),
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) =>
            StatEmptyState(icon: Icons.error_outline, message: empty),
      ),
    );
  }

  static const _rankingUnits = [
    ExposureUnit.hours,
    ExposureUnit.saltHours,
    ExposureUnit.coldDives,
    ExposureUnit.o2Hours,
    ExposureUnit.deepCycles,
    ExposureUnit.cycles,
  ];

  String _unitLabel(AppLocalizations l10n, ExposureUnit unit) => switch (unit) {
    ExposureUnit.hours => l10n.statistics_equipment_exposureUnit_hours,
    ExposureUnit.saltHours => l10n.statistics_equipment_exposureUnit_saltHours,
    ExposureUnit.coldDives => l10n.statistics_equipment_exposureUnit_coldDives,
    ExposureUnit.o2Hours => l10n.statistics_equipment_exposureUnit_o2Hours,
    ExposureUnit.deepCycles =>
      l10n.statistics_equipment_exposureUnit_deepCycles,
    ExposureUnit.cycles => l10n.statistics_equipment_exposureUnit_cycles,
    ExposureUnit.days ||
    ExposureUnit.dives => l10n.statistics_equipment_exposureUnit_hours,
  };

  /// The row's unit word, lower case after the number.
  String _countLabel(AppLocalizations l10n, ExposureUnit unit) =>
      _unitLabel(l10n, unit).toLowerCase();

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
