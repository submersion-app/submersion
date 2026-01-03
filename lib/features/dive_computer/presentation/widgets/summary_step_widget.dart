import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../../features/dive_log/domain/entities/dive_computer.dart';
import '../providers/download_providers.dart';

/// Widget for the summary step of the discovery wizard.
class SummaryStepWidget extends ConsumerWidget {
  final DiveComputer? computer;
  final VoidCallback onDone;
  final VoidCallback onViewDives;

  const SummaryStepWidget({
    super.key,
    required this.computer,
    required this.onDone,
    required this.onViewDives,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final diveCount = downloadState.downloadedDives.length;
    final importResult = downloadState.importResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Success icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.check,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Download Complete!',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),

          // Summary
          Text(
            '$diveCount ${diveCount == 1 ? 'dive' : 'dives'} downloaded',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Computer card
          if (computer != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.watch,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            computer!.displayName,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            computer!.fullName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Import stats
          if (importResult != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatRow(
                      context,
                      Icons.add_circle_outline,
                      'Imported',
                      '${importResult.imported}',
                      colorScheme.primary,
                    ),
                    if (importResult.skipped > 0)
                      _buildStatRow(
                        context,
                        Icons.skip_next,
                        'Skipped (duplicates)',
                        '${importResult.skipped}',
                        colorScheme.onSurfaceVariant,
                      ),
                    if (importResult.updated > 0)
                      _buildStatRow(
                        context,
                        Icons.update,
                        'Updated',
                        '${importResult.updated}',
                        colorScheme.secondary,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Actions
          FilledButton.icon(
            onPressed: onViewDives,
            icon: const Icon(Icons.list),
            label: const Text('View Dives'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
