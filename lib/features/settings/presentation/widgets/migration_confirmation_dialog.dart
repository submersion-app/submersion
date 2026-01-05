import 'package:flutter/material.dart';

/// Dialog to confirm database migration between locations
class MigrationConfirmationDialog extends StatelessWidget {
  final String fromPath;
  final String toPath;
  final bool isMovingToCustom;

  const MigrationConfirmationDialog({
    super.key,
    required this.fromPath,
    required this.toPath,
    required this.isMovingToCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Move Database?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your database will be moved:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // From path
            _buildPathSection(
              context,
              label: 'From',
              path: fromPath,
              icon: Icons.folder_open,
            ),
            const SizedBox(height: 12),

            // Arrow
            const Center(child: Icon(Icons.arrow_downward, color: Colors.grey)),
            const SizedBox(height: 12),

            // To path
            _buildPathSection(
              context,
              label: 'To',
              path: toPath,
              icon: Icons.folder,
            ),

            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A backup will be created before the move. Your data will not be lost.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            // Cloud sync warning (only when moving to custom folder)
            if (isMovingToCustom) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      size: 20,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'App-managed cloud sync will be disabled. Your folder\'s sync service will handle synchronization.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Move Database'),
        ),
      ],
    );
  }

  Widget _buildPathSection(
    BuildContext context, {
    required String label,
    required String path,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
