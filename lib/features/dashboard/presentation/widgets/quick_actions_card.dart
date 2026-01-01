import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/dives/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Log Dive'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/statistics'),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Statistics'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/sites/new'),
                  icon: const Icon(Icons.location_on),
                  label: const Text('Add Site'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
