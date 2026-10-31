import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/presentation/formatters/tank_configuration_labels.dart';
import 'package:submersion/features/insights/presentation/insights_dive_filters.dart';
import 'package:submersion/features/insights/presentation/open_chart_dives.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives by how their tanks were carried, on the Gas page (issue #3421).
///
/// Two groups of bars: every dive counts once under Configuration, so those
/// shares add up to the whole; Extras overlap (a sidemount dive with a stage
/// and a deco gas counts under both), so each is a share of all dives and
/// they are not parts of a whole. Rows with no dives are left out, and
/// tapping a row opens the dives it counted (#3804).
class TankConfigurationCard extends ConsumerWidget {
  const TankConfigurationCard({super.key});

  /// Wide enough for a count and its share, such as "131 · 62%".
  static const double _countWidth = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(tankConfigurationStatsProvider);
    return StatSectionCard(
      title: l10n.insights_gas_tankConfig_title,
      subtitle: l10n.insights_gas_tankConfig_subtitle,
      child: statsAsync.when(
        data: (stats) => stats.totalDives == 0
            ? StatEmptyState(
                icon: MdiIcons.divingScubaTank,
                message: l10n.insights_gas_tankConfig_empty,
              )
            : _content(context, ref, stats),
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_gas_tankConfig_error,
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    TankConfigurationStats stats,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String countAndShare(int count) =>
        l10n.insights_gas_tankConfig_countAndPercent(
          count,
          percent.format(count / stats.totalDives),
        );

    /// A bar per non-zero count, largest first. Each row keeps its key, so
    /// tapping it opens that key's dives whatever the sort did.
    Widget bars<T>(
      Map<T, int> counts,
      String Function(T) label,
      Color color,
      DiveFilterState Function(DiveFilterState scope, T key) filter,
    ) {
      final entries = counts.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return HorizontalCategoryBarChart(
        data: [for (final e in entries) (label: label(e.key), count: e.value)],
        barColor: color,
        formatCount: countAndShare,
        countWidth: _countWidth,
        scaleTo: stats.totalDives,
        onRowTap: (index) => openFilteredChartDives(
          context,
          ref,
          chart: l10n.insights_gas_tankConfig_title,
          row: label(entries[index].key),
          narrow: (scope) => filter(scope, entries[index].key),
        ),
      );
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(l10n.insights_gas_tankConfig_configurationHeading),
        bars(
          stats.baseCounts,
          (c) => tankBaseConfigurationLabel(l10n, c),
          theme.colorScheme.primary,
          tankConfigDivesFilter,
        ),
        if (stats.extraCounts.values.any((n) => n > 0)) ...[
          const SizedBox(height: 12),
          heading(l10n.insights_gas_tankConfig_extrasHeading),
          bars(
            stats.extraCounts,
            (e) => tankConfigurationExtraLabel(l10n, e),
            theme.colorScheme.tertiary,
            tankExtraDivesFilter,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.insights_gas_tankConfig_note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
