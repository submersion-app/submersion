import 'package:flutter/material.dart';

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
