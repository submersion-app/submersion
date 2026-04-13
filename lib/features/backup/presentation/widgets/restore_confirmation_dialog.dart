import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation dialog shown before restoring from a backup.
///
/// Displays backup details and warns about data replacement.
/// For pre-migration backups, branches on schema version compatibility.
class RestoreConfirmationDialog extends StatelessWidget {
  final BackupRecord record;
  final int currentSchemaVersion;

  const RestoreConfirmationDialog({
    super.key,
    required this.record,
    required this.currentSchemaVersion,
  });

  /// Shows the dialog and returns true if the user confirms.
  static Future<bool> show(
    BuildContext context,
    BackupRecord record, {
    required int currentSchemaVersion,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RestoreConfirmationDialog(
        record: record,
        currentSchemaVersion: currentSchemaVersion,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (record.type == BackupType.preMigration) {
      return _buildPreMigration(context);
    }
    return _buildManual(context);
  }

  Widget _buildManual(BuildContext context) {
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
                if ((record.diveCount ?? 0) > 0 || (record.siteCount ?? 0) > 0)
                  Text(
                    '${record.diveCount ?? 0} dives, ${record.siteCount ?? 0} sites',
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

  Widget _buildPreMigration(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();
    final fromSchemaVersion = record.fromSchemaVersion;
    final toSchemaVersion = record.toSchemaVersion;
    final appVersion = record.appVersion ?? 'unknown version';
    final timestamp = dateFormat.format(record.timestamp);

    if (fromSchemaVersion == null || toSchemaVersion == null) {
      return AlertDialog(
        title: const Text('Restore pre-migration backup'),
        content: Text(
          'This backup was made on $timestamp by app $appVersion, but its '
          'database migration metadata is incomplete.\n\n'
          'The app cannot verify whether restoring this backup is safe, '
          'so restore is disabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    final fromV = fromSchemaVersion;
    final toV = toSchemaVersion;

    if (currentSchemaVersion < fromV) {
      // Hard block: backup is from a newer app than currently installed.
      return AlertDialog(
        title: const Text('Restore pre-migration backup'),
        content: Text(
          'This backup is newer than your app. Install a newer app '
          'version to restore it.\n\n'
          'Backup made on $timestamp by app $appVersion (database v$fromV).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    if (currentSchemaVersion == fromV) {
      // Green path: database schema matches the backup's pre-migration
      // state; restore is safe.
      return AlertDialog(
        title: const Text('Restore pre-migration backup'),
        content: Text(
          'This backup was made on $timestamp by app $appVersion, just '
          'before upgrading the database from v$fromV to v$toV.\n\n'
          "Your app's database schema matches this backup, so "
          'restore is safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      );
    }

    // currentSchemaVersion > fromV — warning path.
    return AlertDialog(
      title: const Text('Restore pre-migration backup'),
      content: Text(
        'This backup was made on $timestamp by app $appVersion, just '
        'before upgrading the database from v$fromV to v$toV.\n\n'
        'You are running a newer app (database v$currentSchemaVersion).\n\n'
        'Restoring now will re-run the v$fromV \u2192 v$toV database upgrade '
        'on your restored data \u2014 the same upgrade that was about to run '
        'originally. If that upgrade caused the problem, you will hit '
        'the same issue again.\n\n'
        'To restore safely: install app $appVersion or earlier, then restore '
        'this backup from that older app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Restore anyway'),
        ),
      ],
    );
  }
}
