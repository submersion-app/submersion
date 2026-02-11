import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
      title: Text(context.l10n.settings_migration_dialog_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.settings_migration_dialog_message,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // From path
            _buildPathSection(
              context,
              label: context.l10n.settings_migration_from,
              path: fromPath,
              icon: Icons.folder_open,
            ),
            const SizedBox(height: 12),

            // Arrow
            const Center(
              child: ExcludeSemantics(
                child: Icon(Icons.arrow_downward, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),

            // To path
            _buildPathSection(
              context,
              label: context.l10n.settings_migration_to,
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
                      context.l10n.settings_migration_backupInfo,
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
                        context.l10n.settings_migration_cloudSyncWarning,
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
          child: Text(context.l10n.settings_migration_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.settings_migration_moveDatabase),
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
