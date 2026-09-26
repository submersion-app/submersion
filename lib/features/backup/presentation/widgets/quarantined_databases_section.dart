import 'package:flutter/material.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/quarantined_database.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/quarantined_database_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Database copies a restore kept next to the live database instead of
/// deleting them, with restore and delete for each (issue #1923).
///
/// Renders nothing until at least one copy exists, which is the common case,
/// and nothing while the folder is being read: the spinner would be a flash
/// on every visit to Backups for something almost nobody has.
///
/// Restore is offered only for a copy this build can open, through the same
/// confirmation dialog and operation as a history restore. Delete is always
/// offered, because a copy that cannot be restored still costs disk space;
/// it is never automatic, because each copy was kept precisely because it
/// could not be proven disposable.
class QuarantinedDatabasesSection extends ConsumerWidget {
  const QuarantinedDatabasesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copies = ref.watch(quarantinedDatabasesProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final Widget body;
    switch (copies) {
      case AsyncData(:final value) when value.isNotEmpty:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.backup_quarantined_explanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final copy in value) _QuarantinedDatabaseTile(copy: copy),
          ],
        );
      case AsyncError():
        body = Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.backup_quarantined_loadFailed,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        );
      default:
        return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.backup_quarantined_sectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        body,
        const Divider(),
      ],
    );
  }
}

enum _Action { restore, delete }

class _QuarantinedDatabaseTile extends ConsumerWidget {
  const _QuarantinedDatabaseTile({required this.copy});

  final QuarantinedDatabase copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final busy =
        ref.watch(backupOperationProvider).status ==
        BackupOperationStatus.inProgress;

    final date = units.formatDateTime(copy.quarantinedAt.toLocal(), l10n: l10n);
    final size = formatBytes(copy.sizeBytes);
    final version = copy.schemaVersion;
    final detail = version == null || version < 1
        ? l10n.backup_quarantined_detail(date, size)
        : l10n.backup_quarantined_detailWithVersion(date, size, version);
    final problem = switch (copy.status) {
      QuarantinedDatabaseStatus.restorable => null,
      QuarantinedDatabaseStatus.needsNewerApp =>
        l10n.backup_quarantined_status_needsNewerApp,
      QuarantinedDatabaseStatus.unreadable =>
        l10n.backup_quarantined_status_unreadable,
      QuarantinedDatabaseStatus.incomplete =>
        l10n.backup_quarantined_status_incomplete,
    };

    return ListTile(
      key: ValueKey('quarantinedDatabase_${copy.filename}'),
      leading: const Icon(Icons.restore_page_outlined),
      title: Text(switch (copy.kind) {
        QuarantineKind.preRestore => l10n.backup_quarantined_kind_preRestore,
        QuarantineKind.restoreRejected =>
          l10n.backup_quarantined_kind_restoreRejected,
      }),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail),
          if (problem != null)
            Text(
              problem,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      isThreeLine: problem != null,
      trailing: PopupMenuButton<_Action>(
        enabled: !busy,
        onSelected: (action) => switch (action) {
          _Action.restore => _restore(context, ref),
          _Action.delete => _delete(context, ref),
        },
        itemBuilder: (context) => [
          if (copy.isRestorable)
            PopupMenuItem(
              value: _Action.restore,
              child: ListTile(
                leading: const Icon(Icons.restore),
                title: Text(context.l10n.backup_history_action_restore),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          PopupMenuItem(
            value: _Action.delete,
            child: ListTile(
              leading: Icon(Icons.delete, color: theme.colorScheme.error),
              title: Text(
                context.l10n.backup_history_action_delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    // Read before the dialog: it outlives this tile if the list rebuilds
    // underneath it, and `ref` on an unmounted element throws.
    final notifier = ref.read(backupOperationProvider.notifier);
    final offerReplace = ref.read(cloudStorageProviderProvider) != null;
    final container = ProviderScope.containerOf(context, listen: false);

    final mode = await RestoreConfirmationDialog.show(
      context,
      BackupRecord(
        id: 'quarantined',
        filename: copy.filename,
        timestamp: copy.quarantinedAt.toLocal(),
        sizeBytes: copy.sizeBytes,
        location: BackupLocation.local,
        diveCount: 0,
        siteCount: 0,
      ),
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
      offerReplace: offerReplace,
    );
    if (mode == null) return;

    // A successful restore restarts the app; a failed one reports through
    // the operation status on the Backups page.
    await notifier.restoreFromDatabaseCopy(copy.path, mode: mode);
    // Re-read either way: folding the copy's journal in changes its size
    // even when the restore then fails.
    container.invalidate(quarantinedDatabasesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(quarantinedDatabaseServiceProvider);
    final container = ProviderScope.containerOf(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_quarantined_delete_title),
        content: Text(l10n.backup_quarantined_delete_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.backup_delete_dialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.backup_delete_dialog_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    String message;
    try {
      await service.delete(copy);
      message = l10n.backup_quarantined_deleted;
    } catch (_) {
      message = l10n.backup_quarantined_deleteFailed;
    }
    // Refreshed either way: a failed delete may still have removed part of
    // the copy, and the list should show what is really there.
    container.invalidate(quarantinedDatabasesProvider);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
