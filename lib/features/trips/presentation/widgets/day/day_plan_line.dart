import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "2 of 3 planned dives" for a day under way or done, "3 dives planned" for
/// a day ahead.
class DayPlanLine extends StatelessWidget {
  final DayPlanProgress progress;

  /// Overrides the default muted labelSmall style.
  final TextStyle? style;

  const DayPlanLine({super.key, required this.progress, this.style});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Text(
      progress.upcoming
          ? l10n.trips_itinerary_plannedDives(progress.planned)
          : l10n.trips_day_planProgress(progress.logged, progress.planned),
      style:
          style ??
          theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
    );
  }
}
