import 'package:flutter/material.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_tile.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_passphrase_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every backup this device knows of, with pin, Restore and Delete,
/// unchanged inside (spec section 8.2).
class BackupHistorySection extends ConsumerWidget {
  const BackupHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(backupHistoryProvider);
    final origins = ref.watch(backupOriginResolverProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.l10n.backup_section_history,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.backup_history_error(error.toString()),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    context.l10n.backup_history_empty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final record in history)
                  BackupHistoryTile(
                    record: record,
                    origin: origins.originOf(record.filename),
                    leadingIcon: _locationIcon(record.location),
                    onPinToggle: () => _togglePin(context, ref, record),
                    onRestore: () => _restore(context, ref, record),
                    onDelete: () => _delete(context, ref, record),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    BackupRecord record,
  ) async {
    final service = ref.read(backupServiceProvider);
    try {
      if (record.pinned) {
        await service.unpinBackup(record.id);
      } else {
        // Adopts a cloud backup the history had no record of.
        await service.pinRecord(record);
      }
      ref.invalidate(backupHistoryProvider);
    } catch (e, stackTrace) {
      debugPrint('Failed to update pin state: $e\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.backup_history_pinError)),
      );
    }
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    BackupRecord record,
  ) async {
    final mode = await RestoreConfirmationDialog.show(
      context,
      record,
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
      offerReplace: ref.read(cloudStorageProviderProvider) != null,
    );
    if (mode == null) return;
    try {
      await ref
          .read(backupOperationProvider.notifier)
          .restoreFromBackup(record, mode: mode);
    } on BackupEncryptedException {
      if (!context.mounted) return;
      await showEncryptionPassphraseDialog(
        context,
        title: context.l10n.settings_backupEncryption_restoreUnlockTitle,
        hint: context.l10n.settings_backupEncryption_restoreUnlockHint,
        onSubmit: (secret) => ref
            .read(backupOperationProvider.notifier)
            .restoreFromBackup(record, mode: mode, encryptionSecret: secret),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BackupRecord record,
  ) async {
    // A cloud-only row may be another device's only copy (issue #3214).
    final mayBeShared = await ref
        .read(backupServiceProvider)
        .mayBeAnotherDevicesCopy(record);
    if (!context.mounted) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backup_delete_dialog_title),
        content: Text(
          mayBeShared
              ? l10n.backup_delete_dialog_content_otherDevice
              : l10n.backup_delete_dialog_content,
        ),
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
    if (confirmed ?? false) {
      ref.read(backupOperationProvider.notifier).deleteBackup(record);
    }
  }
}

IconData _locationIcon(BackupLocation location) => switch (location) {
  BackupLocation.local => Icons.phone_android,
  BackupLocation.cloud => Icons.cloud,
  BackupLocation.both => Icons.cloud_done,
};
