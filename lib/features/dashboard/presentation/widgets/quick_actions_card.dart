import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// A card showing quick action buttons for common tasks
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.l10n.dashboard_quickActions_sectionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Tooltip(
                  message: context.l10n.dashboard_quickActions_logDiveTooltip,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/dives/new'),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.dashboard_quickActions_logDive),
                  ),
                ),
                Tooltip(
                  message: context.l10n.dashboard_quickActions_planDiveTooltip,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.go('/planning/dive-planner'),
                    icon: const Icon(Icons.edit_calendar),
                    label: Text(context.l10n.dashboard_quickActions_planDive),
                  ),
                ),
                Tooltip(
                  message:
                      context.l10n.dashboard_quickActions_statisticsTooltip,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/statistics'),
                    icon: const Icon(Icons.bar_chart),
                    label: Text(context.l10n.dashboard_quickActions_statistics),
                  ),
                ),
                Tooltip(
                  message: context.l10n.dashboard_quickActions_addSiteTooltip,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/sites/new'),
                    icon: const Icon(Icons.location_on),
                    label: Text(context.l10n.dashboard_quickActions_addSite),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
