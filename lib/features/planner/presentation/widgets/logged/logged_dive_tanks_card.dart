import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_chip.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Tanks card for a logged dive picked in the series bar (issue #3565):
/// the same card and chips as a planned dive's, read-only, each with the
/// pressure it started and ended at.
class LoggedDiveTanksCard extends ConsumerWidget {
  const LoggedDiveTanksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logged = ref.watch(viewedLoggedDiveProvider);
    if (logged == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final tanks = ref.watch(diveProvider(logged.id)).value?.tanks ?? const [];

    String pressures(double? start, double? end) => [
      if (start != null) units.formatPressure(start),
      if (end != null) units.formatPressure(end),
    ].join(' → ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    MdiIcons.divingScubaTank,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.divePlanner_label_tanks,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tank in tanks)
                  PlanTankChip(
                    tank: tank,
                    role: tank.role,
                    units: units,
                    onEdit: null,
                    pressureLabel:
                        (tank.startPressure == null && tank.endPressure == null)
                        ? null
                        : pressures(tank.startPressure, tank.endPressure),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
