import 'package:flutter/material.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_confirm_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/account_rename_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One account (spec section 7.6): its sign-in state, what it is used for
/// here, Sign in again, an own server's details and folders, then Sign out
/// on this device and Remove from all devices. [accountId] is any roster row
/// of the account.
class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(accountGroupsProvider);
    final group = groupsAsync.value?.holding(accountId);
    return Scaffold(
      appBar: AppBar(
        title: Text(group?.label ?? l10n.settings_connectedAccounts_title),
      ),
      body: switch ((groupsAsync, group)) {
        (_, final AccountGroup g) => _Details(group: g),
        (AsyncError(), _) => Center(
          child: Text(l10n.settings_connectedAccounts_loadError),
        ),
        (AsyncData(), null) => Center(
          child: Text(l10n.settings_connectedAccounts_loadError),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.group});

  final AccountGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isICloud = group.kind == AccountKind.icloud;
    // A build that cannot sign in to the service (no Dropbox app key, no
    // Google client here) offers no sign-in that would fail at once.
    final buildCanSignIn = switch (group.kind) {
      AccountKind.googledrive =>
        ref.watch(googleDriveAvailableProvider).value ?? false,
      AccountKind.dropbox => ref.watch(dropboxConfiguredProvider),
      _ => true,
    };
    final canSignIn =
        !isICloud &&
        group.kind != AccountKind.adobeLightroom &&
        group.status != AccountStatus.unavailable;
    final usages = group.usages;
    final isSyncAccount = usages.any(
      (u) => u.kind == AccountUsageKind.databaseSync,
    );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: Icon(accountKindIcon(group.kind)),
          title: Text(accountStateText(l10n, group.status)),
          subtitle: group.identifier == null ? null : Text(group.identifier!),
        ),
        if (group.usagesKnown)
          ListTile(
            title: Text(
              usages.isEmpty
                  ? l10n.settings_connectedAccounts_usage_none
                  : l10n.settings_accounts_usedHere(
                      usages.map((u) => accountUsageName(l10n, u)).join(', '),
                    ),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(l10n.settings_connectedAccounts_rename),
          onTap: () => _rename(context, ref),
        ),
        if (isICloud)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settings_accounts_icloudManaged),
          ),
        if (canSignIn && buildCanSignIn && !group.isOwnServer)
          ListTile(
            leading: const Icon(Icons.login),
            title: Text(l10n.settings_accounts_signInAgain),
            onTap: () => signInToGroup(context, ref, group),
          ),
        if (group.isOwnServer) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: buildSettingsSectionHeader(
              context,
              l10n.settings_accounts_serverDetails,
            ),
          ),
          OwnServerForm(
            key: ValueKey(group.key),
            existing: group,
            // The sync account's folder stays editable, as on today's S3
            // and WebDAV settings pages; a new folder is a new row, and
            // sync follows it there.
            showSyncFolder: isSyncAccount,
            onSaved: (row) async {
              // Also for the same row: sync reads the legacy settings, which
              // only the switch rewrites from the saved ones.
              if (isSyncAccount) await switchSyncToRow(context, ref, row);
              if (context.mounted) _refresh(context);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: buildSettingsSectionHeader(
              context,
              l10n.settings_accounts_folders,
            ),
          ),
          for (final row in group.rows)
            ListTile(
              dense: true,
              title: Text(group.locationOf(row.id)?.folder ?? row.label),
              subtitle: Text(_roleName(l10n, group, row.id)),
            ),
        ],
        const Divider(),
        // Lightroom has no sign-in here but can still be signed out of.
        if ((canSignIn || group.kind == AccountKind.adobeLightroom) &&
            group.signedInHere)
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.settings_connectedAccounts_disconnectDevice),
            onTap: () => _signOut(context, ref),
          ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          title: Text(
            l10n.settings_accounts_removeEverywhere,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          onTap: () => _remove(context, ref),
        ),
      ],
    );
  }

  /// Gives the account a short name (issue #3522). The name goes on every
  /// row of the account, so whichever row a device sees reads the same.
  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final shown = group.rowFor(AccountRole.sync) ?? group.rows.first;
    final nickname = await showAccountRenameDialog(
      context,
      shown.copyWith(label: group.address, nickname: group.nickname),
    );
    if (nickname == null) return;
    await ref.read(connectedAccountsRepositoryProvider).setNicknameForRows([
      for (final row in group.rows) row.id,
    ], nickname);
  }

  /// Signing out breaks nothing when nothing here uses the account, so it
  /// acts at once, as it always has; used, or unknown, asks first.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final service = ref.read(accountGroupServiceProvider);
    if (!group.usagesKnown || group.usages.isNotEmpty) {
      final confirmed = await confirmAccountAction(
        context,
        title: l10n.settings_connectedAccounts_signOutConfirmTitle,
        paragraphs: [
          group.usagesKnown
              ? l10n.settings_connectedAccounts_signOutConfirmBody(group.label)
              : l10n.settings_connectedAccounts_usage_unknown,
          ?_backupWarning(ref, l10n),
        ],
        usages: group.usages,
        action: l10n.settings_connectedAccounts_disconnectDevice,
      );
      if (!confirmed) return;
    }
    if (!context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    if (_runsSync) await leaveSyncForAccount(container);
    await service.signOut(group);
    _refreshWith(container);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final service = ref.read(accountGroupServiceProvider);
    final confirmed = await confirmAccountAction(
      context,
      title: l10n.settings_connectedAccounts_removeConfirmTitle,
      paragraphs: [
        l10n.settings_connectedAccounts_removeConfirmBody,
        if (!group.usagesKnown)
          l10n.settings_connectedAccounts_usage_unknown
        else if (group.usages.isNotEmpty)
          l10n.settings_connectedAccounts_removeConfirmUsedHere,
        ?_backupWarning(ref, l10n),
      ],
      usages: group.usages,
      // The roster row goes from every device, and what other devices use
      // it for is not known here.
      footer: l10n.settings_connectedAccounts_removeConfirmOtherDevices,
      action: l10n.settings_accounts_removeEverywhere,
    );
    if (!confirmed || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    if (_runsSync) await leaveSyncForAccount(container);
    await service.remove(group);
    _refreshWith(container);
    navigator.maybePop();
  }

  /// Cloud backups ride on sync, so losing the sync account stops them; the
  /// diver hears that before agreeing, as Stop syncing says it.
  String? _backupWarning(WidgetRef ref, AppLocalizations l10n) =>
      _runsSync && ref.read(backupSettingsProvider).cloudBackupEnabled
      ? l10n.settings_cloudSync_signOut_backupWarning
      : null;

  /// Whether this device syncs through the account: its sync usage, never a
  /// row that only sits in the default sync folder.
  bool get _runsSync => group.syncRowHere != null;

  void _refresh(BuildContext context) =>
      _refreshWith(ProviderScope.containerOf(context, listen: false));

  /// A sign-out touches only the keychain, so nothing in the database ticks;
  /// every reader of the account's state must recompute, including the
  /// setup items behind the Settings > Data rows.
  void _refreshWith(ProviderContainer container) {
    refreshAccountState(container.invalidate);
    // Signing out of the WebDAV sync account clears the sync settings too.
    if (group.kind == AccountKind.webdav) {
      container.invalidate(webdavConfigProvider);
    }
  }
}

String _roleName(AppLocalizations l10n, AccountGroup group, String rowId) =>
    switch (group.roles[rowId]) {
      AccountRole.sync => l10n.settings_accounts_usage_sync,
      AccountRole.media => l10n.settings_accounts_usage_photos,
      AccountRole.library =>
        l10n.settings_connectedAccounts_usage_sharedLibrary(
          (group.locationOf(rowId)?.folder ?? '').split('/').last,
        ),
      null => l10n.settings_accounts_folder_other,
    };
