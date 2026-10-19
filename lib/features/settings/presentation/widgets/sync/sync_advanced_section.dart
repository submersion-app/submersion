import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/pages/sync_devices_page.dart';
import 'package:submersion/features/settings/presentation/pages/sync_encryption_page.dart';
import 'package:submersion/features/settings/presentation/pages/troubleshoot_sync_page.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/replace_cloud_library_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything the Sync page has besides its account, status, automatic sync
/// and Sync now, re-parented under one Advanced header (spec section 8.1).
class SyncAdvancedSection extends ConsumerWidget {
  const SyncAdvancedSection({super.key, required this.hasProvider});

  /// Replace and Stop need an account to act on.
  final bool hasProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final behavior = ref.watch(syncBehaviorProvider);
    final customFolder = ref.watch(isCloudSyncDisabledByCustomFolderProvider);
    // The two companions only add to automatic sync; greyed out without it.
    final companionsEnabled = behavior.autoSyncEnabled && !customFolder;
    // Recovery and replace reset sync identity and cloud files; racing them
    // against a running sync would have the writer publishing under state
    // they are about to wipe. A sync ERROR is not `syncing`, so a stuck user
    // still reaches Troubleshoot.
    final isSyncing = ref.watch(syncStateProvider).status == SyncStatus.syncing;
    void push(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.settings_cloudSync_header_advanced,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          key: const Key('sync-also-at-launch'),
          title: Text(l10n.settings_sync_alsoAtLaunch),
          subtitle: Text(l10n.settings_cloudSync_syncOnLaunch_subtitle),
          value: behavior.syncOnLaunch,
          onChanged: companionsEnabled
              ? (v) =>
                    ref.read(syncBehaviorProvider.notifier).setSyncOnLaunch(v)
              : null,
        ),
        SwitchListTile(
          key: const Key('sync-also-on-return'),
          title: Text(l10n.settings_sync_alsoOnReturn),
          subtitle: Text(l10n.settings_cloudSync_syncOnResume_subtitle),
          value: behavior.syncOnResume,
          onChanged: companionsEnabled
              ? (v) =>
                    ref.read(syncBehaviorProvider.notifier).setSyncOnResume(v)
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.settings_sync_encryption),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const SyncEncryptionPage()),
        ),
        ListTile(
          leading: const Icon(Icons.devices_outlined),
          title: Text(l10n.settings_sync_devices),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const SyncDevicesPage()),
        ),
        ListTile(
          leading: const Icon(Icons.build),
          title: Text(l10n.settings_sync_troubleshoot),
          subtitle: Text(l10n.settings_cloudSync_troubleshoot_tileSubtitle),
          enabled: !isSyncing,
          onTap: isSyncing ? null : () => push(const TroubleshootSyncPage()),
        ),
        if (hasProvider) ...[
          ListTile(
            leading: Icon(
              Icons.published_with_changes,
              color: theme.colorScheme.error,
            ),
            title: Text(l10n.settings_sync_replaceLibrary),
            subtitle: Text(l10n.settings_cloudSync_replaceLibrary_tileSubtitle),
            enabled: !isSyncing,
            onTap: isSyncing ? null : () => _replace(context, ref),
          ),
          ListTile(
            key: const Key('sync-stop'),
            leading: const Icon(Icons.sync_disabled),
            title: Text(l10n.settings_sync_stop),
            subtitle: Text(l10n.settings_sync_stop_subtitle),
            onTap: () => _confirmStop(context, ref),
          ),
        ],
      ],
    );
  }

  /// Gathers the blast radius, then confirms: the preflight runs before the
  /// dialog so the confirmation can name what is about to be overwritten.
  Future<void> _replace(BuildContext context, WidgetRef ref) async {
    final preflight = await ref
        .read(syncStateProvider.notifier)
        .replacePreflight();
    if (!context.mounted) return;
    await showReplaceCloudLibraryDialog(context, ref, preflight);
  }

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    // Cloud backup uploads ride on the sync provider; losing it changes where
    // backups land, which the diver must hear before agreeing.
    final backupWarning = ref.read(backupSettingsProvider).cloudBackupEnabled
        ? '\n\n${l10n.settings_cloudSync_signOut_backupWarning}'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_sync_stop_confirmTitle),
        content: Text('${l10n.settings_sync_stop_confirmBody}$backupWarning'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settings_sync_stop),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await stopSyncingOnThisDevice(ref);
    await ref.read(backupSettingsProvider.notifier).disableCloudBackup();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settings_sync_stopped)));
    }
  }
}

/// Stops sync on this device (spec section 8.1): the sync selection and its
/// metadata are cleared, as Sign out did, but no provider is signed out, so
/// the account stays signed in for its other uses and for switching back.
Future<void> stopSyncingOnThisDevice(WidgetRef ref) async {
  final repository = ref.read(syncRepositoryProvider);
  await repository.setCloudProvider(null);
  await repository.setRemoteFileId(null);
  ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
  await ref.read(syncInitializerProvider).saveProvider(null);
  ref.invalidate(webdavConfigProvider);
  refreshAccountState(ref.invalidate);
  await ref.read(syncStateProvider.notifier).refreshState();
}
