import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_passphrase_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shared unlock flow: prompt for the passphrase/recovery code, unwrap the
/// key from the cloud keyslot file, activate the session, and re-run sync.
/// Used by the section's locked tile, the sync-page banner, and the
/// Troubleshoot screen. Returns true when unlocked.
Future<bool> runEncryptionUnlockFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  // Resolve the provider up front and capture it for the closure. With no
  // provider there is nothing to unlock against, so bail before showing the
  // dialog rather than letting onSubmit succeed silently (which would close
  // the dialog and trigger a pointless sync without any key).
  final provider = ref.read(cloudStorageProviderProvider);
  if (provider == null) return false;
  final l10n = context.l10n;
  final unlocked = await showEncryptionPassphraseDialog(
    context,
    title: l10n.settings_cloudSync_encryption_unlockTitle,
    hint: l10n.settings_cloudSync_encryption_unlockHint,
    onSubmit: (secret) async {
      final key = await ref
          .read(syncEncryptionServiceProvider)
          .unlock(rawProvider: provider, secret: secret);
      await ref.read(encryptionKeyNotifierProvider.notifier).setUnlocked(key);
    },
  );
  if (unlocked != null) {
    unawaited(ref.read(syncStateProvider.notifier).performSync());
    return true;
  }
  return false;
}

/// The "End-to-end encryption" section of the Cloud Sync page. Renders one
/// of three states -- off, on+unlocked, on+locked -- and orchestrates the
/// lifecycle flows against the encryption service and sync notifier.
class EncryptionSettingsSection extends ConsumerStatefulWidget {
  const EncryptionSettingsSection({super.key});

  @override
  ConsumerState<EncryptionSettingsSection> createState() =>
      _EncryptionSettingsSectionState();
}

class _EncryptionSettingsSectionState
    extends ConsumerState<EncryptionSettingsSection> {
  @override
  void initState() {
    super.initState();
    // Surface a stored key as an unlocked session on first paint (the sync
    // notifier does the same before every sync; this covers pure display).
    Future.microtask(
      () => ref.read(encryptionKeyNotifierProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(encryptionKeyNotifierProvider);
    final enabled = ref.watch(syncPreferencesProvider).syncEncryptionEnabled;
    final hasProvider = ref.watch(cloudStorageProviderProvider) != null;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          l10n.settings_cloudSync_encryption_title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ];

    if (!enabled) {
      children.add(
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.settings_cloudSync_encryption_enable),
          subtitle: Text(
            hasProvider
                ? l10n.settings_cloudSync_encryption_subtitleOff
                : l10n.settings_cloudSync_encryption_subtitleNeedsProvider,
          ),
          enabled: hasProvider,
          onTap: hasProvider ? () => _enable(context) : null,
        ),
      );
    } else if (session == null) {
      children.add(
        ListTile(
          leading: const Icon(Icons.lock_clock),
          title: Text(l10n.settings_cloudSync_encryption_statusLocked),
          subtitle: Text(
            l10n.settings_cloudSync_encryption_statusLockedSubtitle,
          ),
          trailing: FilledButton.tonal(
            onPressed: () => _unlock(context),
            child: Text(l10n.settings_cloudSync_encryption_enterPassphrase),
          ),
        ),
      );
    } else {
      children.addAll([
        ListTile(
          leading: Icon(
            Icons.lock,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(l10n.settings_cloudSync_encryption_statusOn),
          subtitle: Text(l10n.settings_cloudSync_encryption_statusOnSubtitle),
        ),
        ListTile(
          leading: const Icon(Icons.password),
          title: Text(l10n.settings_cloudSync_encryption_changePassphrase),
          onTap: () => _changePassphrase(context),
        ),
        ListTile(
          leading: const Icon(Icons.key),
          title: Text(l10n.settings_cloudSync_encryption_regenerateRecovery),
          subtitle: Text(
            l10n.settings_cloudSync_encryption_regenerateRecoveryWarn,
          ),
          onTap: () => _regenerateRecovery(context),
        ),
        ListTile(
          leading: const Icon(Icons.lock_open),
          title: Text(l10n.settings_cloudSync_encryption_disable),
          onTap: () => _disable(context),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Future<({String deviceId, String? deviceName, String? appVersion})>
  _markerIdentity() async {
    String deviceId;
    try {
      deviceId = await ref.read(syncRepositoryProvider).getDeviceId();
    } catch (_) {
      deviceId = 'unknown';
    }
    String? deviceName;
    try {
      deviceName = Platform.localHostname;
    } catch (_) {
      deviceName = null;
    }
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = null;
    }
    return (deviceId: deviceId, deviceName: deviceName, appVersion: appVersion);
  }

  Future<void> _enable(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EnableEncryptionDialog(
        onEnable: (passphrase) async {
          final provider = ref.read(cloudStorageProviderProvider)!;
          final identity = await _markerIdentity();
          final result = await ref
              .read(syncEncryptionServiceProvider)
              .enable(
                rawProvider: provider,
                passphrase: passphrase,
                epochStore: ref.read(libraryEpochStoreProvider),
                deviceId: identity.deviceId,
                deviceName: identity.deviceName,
                appVersion: identity.appVersion,
              );
          final key = await ref.read(encryptionKeyStoreProvider).loadKey();
          if (key != null) {
            await ref
                .read(encryptionKeyNotifierProvider.notifier)
                .setUnlocked(key);
          }
          return result.recoveryCode;
        },
        onFinished: (deletePlaintextBackups) async {
          if (deletePlaintextBackups) {
            try {
              await ref
                  .read(backupServiceProvider)
                  .deletePlaintextCloudBackups();
            } catch (_) {
              // Non-fatal: retention pruning ages plaintext backups out.
            }
          }
          // Consumes the pending replace: publishes the encrypted library.
          unawaited(ref.read(syncStateProvider.notifier).performSync());
        },
      ),
    );
  }

  Future<void> _unlock(BuildContext context) =>
      runEncryptionUnlockFlow(context, ref);

  Future<void> _changePassphrase(BuildContext context) async {
    await showChangePassphraseDialog(
      context,
      onSubmit: (current, next) => ref
          .read(syncEncryptionServiceProvider)
          .changePassphrase(
            rawProvider: ref.read(cloudStorageProviderProvider)!,
            currentSecret: current,
            newPassphrase: next,
          ),
    );
  }

  Future<void> _regenerateRecovery(BuildContext context) async {
    final l10n = context.l10n;
    String? newCode;
    final confirmed = await showEncryptionPassphraseDialog(
      context,
      title: l10n.settings_cloudSync_encryption_regenerateRecovery,
      onSubmit: (secret) async {
        newCode = await ref
            .read(syncEncryptionServiceProvider)
            .regenerateRecoveryCode(
              rawProvider: ref.read(cloudStorageProviderProvider)!,
              passphrase: secret,
            );
      },
    );
    if (confirmed == null || newCode == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RecoveryCodeResultDialog(code: newCode!),
    );
  }

  Future<void> _disable(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_cloudSync_encryption_disable),
        content: Text(l10n.settings_cloudSync_encryption_disableWarn),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settings_cloudSync_encryption_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_cloudSync_encryption_disable),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final identity = await _markerIdentity();
    final service = ref.read(syncEncryptionServiceProvider);
    await service.disable(
      epochStore: ref.read(libraryEpochStoreProvider),
      deviceId: identity.deviceId,
      deviceName: identity.deviceName,
      appVersion: identity.appVersion,
    );
    // Drop the session so the provider wrap reverts to raw (the STORED key
    // survives for old encrypted backups), republish plaintext, then remove
    // the now-orphaned keyslot file.
    await ref.read(encryptionKeyNotifierProvider.notifier).clear();
    await ref.read(syncStateProvider.notifier).performSync();
    final provider = ref.read(cloudStorageProviderProvider);
    if (provider != null) {
      try {
        await service.deleteCloudKeyslots(provider);
      } catch (_) {
        // Non-fatal: the next enable overwrites it.
      }
    }
  }
}

class _RecoveryCodeResultDialog extends StatefulWidget {
  final String code;

  const _RecoveryCodeResultDialog({required this.code});

  @override
  State<_RecoveryCodeResultDialog> createState() =>
      _RecoveryCodeResultDialogState();
}

class _RecoveryCodeResultDialogState extends State<_RecoveryCodeResultDialog> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_cloudSync_encryption_recoveryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_cloudSync_encryption_recoveryExplain),
          const SizedBox(height: 12),
          RecoveryCodeDisplay(code: widget.code),
          CheckboxListTile(
            value: _saved,
            onChanged: (v) => setState(() => _saved = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l10n.settings_cloudSync_encryption_recoverySavedConfirm,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _saved ? () => Navigator.of(context).pop() : null,
          child: Text(l10n.settings_cloudSync_encryption_done),
        ),
      ],
    );
  }
}
