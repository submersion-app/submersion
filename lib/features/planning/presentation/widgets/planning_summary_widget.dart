import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the Planning detail pane shows before a tool is picked.
///
/// The entity lists put a summary here rather than leaving the pane blank, and
/// Planning has something genuinely useful to fill it with: the full list of
/// saved plans, which the phone-only hub row of the same name opens as its
/// own page instead (issue #3551), since a phone has no detail pane for it.
///
/// Deliberately no tool shortcuts. In split view the tool list is permanently
/// visible in the master pane a few hundred pixels to the left, so repeating
/// it here would duplicate rather than add.
class PlanningSummaryWidget extends ConsumerWidget {
  const PlanningSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.l10n.planning_appBar_title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.planning_summary_prompt,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.planning_summary_savedPlans.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.planning_plannedDives_sortTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: () => openSavedPlansSortSheet(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const SavedPlansList(),
      ],
    );
  }
}
