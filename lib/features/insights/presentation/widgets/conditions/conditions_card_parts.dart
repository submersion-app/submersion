import 'package:flutter/material.dart';

import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Heading of one group on the Conditions tab (issue #3118).
class ConditionsGroupHeader extends StatelessWidget {
  const ConditionsGroupHeader({
    super.key,
    required this.title,
    this.isFirst = false,
  });

  final String title;

  /// The first group sits at the top of the page and needs no gap above it.
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// "Based on 42 of 310 dives" under a condition chart.
class ConditionsCoverageLine extends StatelessWidget {
  const ConditionsCoverageLine({
    super.key,
    required this.recorded,
    required this.total,
  });

  final int recorded;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        context.l10n.insights_conditions_coverage(recorded, total),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A new group's header over its single loading spinner or error message.
///
/// The new groups share one query, so each reports its state once rather
/// than once per chart.
class ConditionsGroupStatus extends StatelessWidget {
  const ConditionsGroupStatus({
    super.key,
    required this.title,
    required this.failed,
  });

  final String title;

  /// True for the error message, false for the loading spinner.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConditionsGroupHeader(title: title),
        if (failed)
          StatEmptyState(
            icon: Icons.error_outline,
            message: context.l10n.insights_conditions_weather_error,
          )
        else
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// The shell every new condition card shares: a stat card holding [chart],
/// labelled for screen readers, with the coverage line under it.
class ConditionsChartCard extends StatelessWidget {
  const ConditionsChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.chart,
    required this.recorded,
    required this.total,
  });

  final String title;
  final String subtitle;

  /// Each category or band with its dive count, read after [title].
  final String description;
  final Widget chart;
  final int recorded;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: StatSectionCard(
        title: title,
        subtitle: subtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: context.l10n.insights_conditions_chart_semanticLabel(
                title,
                description,
              ),
              child: chart,
            ),
            ConditionsCoverageLine(recorded: recorded, total: total),
          ],
        ),
      ),
    );
  }
}
