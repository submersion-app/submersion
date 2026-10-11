import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// "Today" marker for the current trip day, filled in the primary colour so it
/// reads on a plain card and on today's tinted header alike.
class TodayChip extends StatelessWidget {
  const TodayChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Chip(
      key: const Key('today-chip'),
      label: Text(context.l10n.trips_story_today),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: colorScheme.primary,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
