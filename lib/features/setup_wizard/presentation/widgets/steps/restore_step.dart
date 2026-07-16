import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/presentation/pages/restore_complete_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_passphrase_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A chosen backup file: its absolute path and display name.
typedef PickedBackupFile = ({String path, String name});

/// Restores a backup file; exits the wizard via the existing
/// RestoreCompletePage -> restartApp() flow.
class RestoreStep extends ConsumerWidget {
  /// [pickBackupFile] is injectable so the restore flow can be exercised
  /// without a real platform file picker; it defaults to file_picker.
  const RestoreStep({super.key, this.pickBackupFile = _pickViaFilePicker});

  final Future<PickedBackupFile?> Function() pickBackupFile;

  static Future<PickedBackupFile?> _pickViaFilePicker() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final path = file.path;
    return path == null ? null : (path: path, name: file.name);
  }

  Future<void> _pickAndRestore(BuildContext context, WidgetRef ref) async {
    final PickedBackupFile? picked;
    try {
      picked = await pickBackupFile();
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (picked == null || !context.mounted) return;

    final file = File(picked.path);
    final record = BackupRecord(
      id: 'setup-wizard',
      filename: picked.name,
      timestamp: await file.lastModified(),
      sizeBytes: await file.length(),
      location: BackupLocation.local,
      diveCount: 0,
      siteCount: 0,
    );
    if (!context.mounted) return;

    final mode = await RestoreConfirmationDialog.show(
      context,
      record,
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    if (mode == null) return;

    final path = picked.path;
    try {
      await ref
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(path, mode: mode);
    } on BackupEncryptedException {
      // Encrypted (.sbe) backups need a passphrase or recovery code. Without
      // this the exception escaped as an unhandled async error and the restore
      // silently did nothing. Prompt, then retry with the secret.
      if (!context.mounted) return;
      await showEncryptionPassphraseDialog(
        context,
        title: context.l10n.settings_backupEncryption_restoreUnlockTitle,
        hint: context.l10n.settings_backupEncryption_restoreUnlockHint,
        onSubmit: (secret) => ref
            .read(backupOperationProvider.notifier)
            .restoreFromFilePath(path, mode: mode, encryptionSecret: secret),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final operation = ref.watch(backupOperationProvider);

    ref.listen<BackupOperationState>(backupOperationProvider, (prev, next) {
      if (next.status == BackupOperationStatus.restoreComplete &&
          context.mounted) {
        RestoreCompletePage.show(context);
      }
    });

    final inProgress = operation.status == BackupOperationStatus.inProgress;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.setup_restore_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            if (inProgress) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(operation.message ?? l10n.setup_restore_inProgress),
            ] else ...[
              if (operation.status == BackupOperationStatus.error &&
                  operation.message != null) ...[
                Text(
                  operation.message!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: () => _pickAndRestore(context, ref),
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.setup_restore_pick),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
