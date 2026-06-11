import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation dialog shown before restoring from a backup.
///
/// Displays backup details and warns about data replacement. When
/// [offerReplace] is true (cloud sync is configured), the user chooses
/// between merging with the cloud library on the next sync (default) and
/// replacing the library everywhere; Replace requires a second confirmation.
/// For pre-migration backups, branches on schema version compatibility
/// (those emergency flows always restore in merge mode).
class RestoreConfirmationDialog extends StatefulWidget {
  final BackupRecord record;
  final int currentSchemaVersion;
  final bool offerReplace;

  const RestoreConfirmationDialog({
    super.key,
    required this.record,
    required this.currentSchemaVersion,
    this.offerReplace = false,
  });

  /// Shows the dialog. Returns the chosen restore mode, or null on cancel.
  static Future<RestoreMode?> show(
    BuildContext context,
    BackupRecord record, {
    required int currentSchemaVersion,
    bool offerReplace = false,
  }) {
    return showDialog<RestoreMode>(
      context: context,
      builder: (_) => RestoreConfirmationDialog(
        record: record,
        currentSchemaVersion: currentSchemaVersion,
        offerReplace: offerReplace,
      ),
    );
  }

  @override
  State<RestoreConfirmationDialog> createState() =>
      _RestoreConfirmationDialogState();
}

class _RestoreConfirmationDialogState extends State<RestoreConfirmationDialog> {
  RestoreMode _mode = RestoreMode.merge;

  @override
  Widget build(BuildContext context) {
    if (widget.record.type == BackupType.preMigration) {
      return _buildPreMigration(context);
    }
    return _buildManual(context);
  }

  Widget _buildManual(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();
    final record = widget.record;

    return AlertDialog(
      title: Text(context.l10n.backup_restore_dialog_title),
      content: SingleChildScrollView(
        child: Column(
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
                  if ((record.diveCount ?? 0) > 0 ||
                      (record.siteCount ?? 0) > 0)
                    Text(
                      '${record.diveCount ?? 0} dives, ${record.siteCount ?? 0} sites',
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(record.formattedSize, style: theme.textTheme.bodySmall),
                ],
              ),
            ),

            // Restore mode choice (only when cloud sync is configured)
            if (widget.offerReplace) ...[
              const SizedBox(height: 12),
              RadioGroup<RestoreMode>(
                groupValue: _mode,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _mode = value);
                },
                child: Column(
                  children: [
                    RadioListTile<RestoreMode>(
                      value: RestoreMode.merge,
                      title: Text(
                        context.l10n.backup_restore_dialog_modeMerge_title,
                      ),
                      subtitle: Text(
                        context.l10n.backup_restore_dialog_modeMerge_subtitle,
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    RadioListTile<RestoreMode>(
                      value: RestoreMode.replace,
                      title: Text(
                        context.l10n.backup_restore_dialog_modeReplace_title,
                      ),
                      subtitle: Text(
                        context.l10n.backup_restore_dialog_modeReplace_subtitle,
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.backup_restore_dialog_cancel),
        ),
        FilledButton(
          onPressed: () => _confirm(context),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(
            _mode == RestoreMode.replace
                ? context.l10n.backup_restore_dialog_restoreReplace
                : context.l10n.backup_restore_dialog_restore,
          ),
        ),
      ],
    );
  }

  /// Confirm the restore. Replace mode gets a second, consequence-spelling
  /// confirmation before the dialog resolves.
  Future<void> _confirm(BuildContext context) async {
    if (_mode == RestoreMode.merge) {
      Navigator.of(context).pop(RestoreMode.merge);
      return;
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_replaceConfirm_title),
        content: Text(l10n.backup_replaceConfirm_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backup_restore_dialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.backup_replaceConfirm_confirm),
          ),
        ],
      ),
    );
    if (sure == true && context.mounted) {
      Navigator.of(context).pop(RestoreMode.replace);
    }
  }

  Widget _buildPreMigration(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();
    final record = widget.record;
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    final fromV = fromSchemaVersion;
    final toV = toSchemaVersion;

    if (widget.currentSchemaVersion < fromV) {
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    if (widget.currentSchemaVersion == fromV) {
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(RestoreMode.merge),
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
        'You are running a newer app (database v${widget.currentSchemaVersion}).\n\n'
        'Restoring now will re-run the v$fromV → v$toV database upgrade '
        'on your restored data — the same upgrade that was about to run '
        'originally. If that upgrade caused the problem, you will hit '
        'the same issue again.\n\n'
        'To restore safely: install app $appVersion or earlier, then restore '
        'this backup from that older app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(RestoreMode.merge),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Restore anyway'),
        ),
      ],
    );
  }
}
