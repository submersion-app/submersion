import 'package:flutter/material.dart';

import '../../../../core/services/database_migration_service.dart';

/// User's choice when an existing database is found
enum ExistingDatabaseChoice {
  /// Use the existing database at the target location
  useExisting,

  /// Replace the existing database with current data
  replace,
}

/// Dialog shown when the target folder already contains a Submersion database
class ExistingDatabaseDialog extends StatefulWidget {
  final ExistingDatabaseInfo existingInfo;
  final ExistingDatabaseInfo? currentInfo;

  const ExistingDatabaseDialog({
    super.key,
    required this.existingInfo,
    this.currentInfo,
  });

  @override
  State<ExistingDatabaseDialog> createState() => _ExistingDatabaseDialogState();
}

class _ExistingDatabaseDialogState extends State<ExistingDatabaseDialog> {
  ExistingDatabaseChoice? _selectedChoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Existing Database Found'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A Submersion database already exists in this folder.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Comparison
            Row(
              children: [
                Expanded(
                  child: _buildDatabaseCard(
                    context,
                    title: 'Existing',
                    info: widget.existingInfo,
                    isExisting: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDatabaseCard(
                    context,
                    title: 'Current',
                    info: widget.currentInfo,
                    isExisting: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Options
            _buildOption(
              context,
              choice: ExistingDatabaseChoice.useExisting,
              title: 'Use existing database',
              subtitle: 'Switch to the database in this folder',
              icon: Icons.folder_open,
            ),
            const SizedBox(height: 8),
            _buildOption(
              context,
              choice: ExistingDatabaseChoice.replace,
              title: 'Replace with my data',
              subtitle: 'Overwrite with your current database',
              icon: Icons.drive_file_move,
            ),

            // Warning for replace
            if (_selectedChoice == ExistingDatabaseChoice.replace) ...[
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
                        'The existing database will be backed up before being replaced.',
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
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedChoice != null
              ? () => Navigator.of(context).pop(_selectedChoice)
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildDatabaseCard(
    BuildContext context, {
    required String title,
    required ExistingDatabaseInfo? info,
    required bool isExisting,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExisting
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (info != null) ...[
            // Primary stats
            _buildStatRow(context, 'Users', info.userCount),
            _buildStatRow(context, 'Dives', info.diveCount),
            _buildStatRow(context, 'Sites', info.siteCount),
            _buildStatRow(context, 'Trips', info.tripCount),
            _buildStatRow(context, 'Buddies', info.buddyCount),
            const SizedBox(height: 6),
            Text(
              info.formattedFileSize,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text(
              'Unknown',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            count.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required ExistingDatabaseChoice choice,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedChoice == choice;

    return InkWell(
      onTap: () => setState(() => _selectedChoice = choice),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
