import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A card showing quick action buttons for common tasks
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboard_quickActions_sectionTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showAddDiveBottomSheet(
                        context: context,
                        onLogManually: () => context.go('/dives/new'),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.dashboard_quickActions_logDive),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.go('/planning/dive-planner'),
                      icon: const Icon(Icons.edit_calendar),
                      label: Text(context.l10n.dashboard_quickActions_planDive),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/statistics'),
                      icon: const Icon(Icons.bar_chart),
                      label: Text(
                        context.l10n.dashboard_quickActions_statistics,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
