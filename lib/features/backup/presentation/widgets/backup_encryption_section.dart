import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_change_password_dialog.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_enable_encryption_dialog.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_recovery_code_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_passphrase_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings section for password-protected backups (issue #580). Two states:
/// off (offer to enable) and on (change password, regenerate recovery code,
/// turn off). Independent of the cloud-sync encryption section.
class BackupEncryptionSection extends ConsumerWidget {
  const BackupEncryptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = ref.watch(
      backupSettingsProvider.select((s) => s.backupEncryptionEnabled),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.settings_backupEncryption_title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (!enabled)
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.settings_backupEncryption_enable),
            subtitle: Text(l10n.settings_backupEncryption_subtitleOff),
            onTap: () => _enable(context, ref),
          )
        else ...[
          ListTile(
            leading: Icon(Icons.lock, color: theme.colorScheme.primary),
            title: Text(l10n.settings_backupEncryption_subtitleOn),
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l10n.settings_backupEncryption_changePassword),
            onTap: () => _changePassword(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.autorenew),
            title: Text(l10n.settings_backupEncryption_regenerateRecovery),
            onTap: () => _regenerate(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.lock_open, color: theme.colorScheme.error),
            title: Text(l10n.settings_backupEncryption_turnOff),
            onTap: () => _turnOff(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupEncryptionServiceProvider);
    final notifier = ref.read(backupSettingsProvider.notifier);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupEnableEncryptionDialog(
        onEnable: (passphrase) async {
          final result = await service.enable(passphrase: passphrase);
          return result.recoveryCode;
        },
        onFinished: () => notifier.setBackupEncryptionEnabled(true),
      ),
    );
    if (ok == true && context.mounted) {
      await _offerReencrypt(context, ref);
    }
  }

  Future<void> _offerReencrypt(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final run = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_backupEncryption_reencryptTitle),
        content: Text(l10n.settings_backupEncryption_reencryptBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settings_backupEncryption_reencryptNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_backupEncryption_reencryptNow),
          ),
        ],
      ),
    );
    if (run != true || !context.mounted) return;
    final result = await ref
        .read(backupServiceProvider)
        .reencryptExistingBackups();
    if (!context.mounted) return;
    // When some backups could not be encrypted, say so explicitly (with a
    // warning color) so the user does not assume everything is now protected.
    final theme = Theme.of(context);
    final hasFailures = result.failed > 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: hasFailures ? theme.colorScheme.error : null,
        content: Text(
          hasFailures
              ? l10n.settings_backupEncryption_reencryptPartial(
                  result.reencrypted,
                  result.failed,
                )
              : l10n.settings_backupEncryption_reencryptDone(
                  result.reencrypted,
                ),
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupEncryptionServiceProvider);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupChangePasswordDialog(
        onSubmit: (current, next) => service.changePassphrase(
          currentSecret: current,
          newPassphrase: next,
        ),
      ),
    );
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final service = ref.read(backupEncryptionServiceProvider);
    String? newCode;
    await showEncryptionPassphraseDialog(
      context,
      title: l10n.settings_backupEncryption_unlockTitle,
      hint: l10n.settings_backupEncryption_unlockHint,
      onSubmit: (secret) async {
        newCode = await service.regenerateRecoveryCode(currentSecret: secret);
      },
    );
    if (newCode == null || !context.mounted) return;
    await showBackupRecoveryCodeDialog(context, code: newCode!);
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final notifier = ref.read(backupSettingsProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_backupEncryption_turnOffTitle),
        content: Text(l10n.settings_backupEncryption_turnOffBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settings_backupEncryption_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_backupEncryption_turnOff),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.setBackupEncryptionEnabled(false);
    }
  }
}
