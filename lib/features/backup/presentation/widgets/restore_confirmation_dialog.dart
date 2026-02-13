import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation dialog shown before restoring from a backup.
///
/// Displays backup details and warns about data replacement.
class RestoreConfirmationDialog extends StatelessWidget {
  final BackupRecord record;

  const RestoreConfirmationDialog({super.key, required this.record});

  /// Shows the dialog and returns true if the user confirms.
  static Future<bool> show(BuildContext context, BackupRecord record) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RestoreConfirmationDialog(record: record),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return AlertDialog(
      title: Text(context.l10n.backup_restore_dialog_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backup details card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(record.timestamp),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.diveCount} dives, ${record.siteCount} sites',
                  style: theme.textTheme.bodySmall,
                ),
                Text(record.formattedSize, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Warning
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.backup_restore_dialog_warning,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Safety note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.backup_restore_dialog_safetyNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.backup_restore_dialog_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(context.l10n.backup_restore_dialog_restore),
        ),
      ],
    );
  }
}
