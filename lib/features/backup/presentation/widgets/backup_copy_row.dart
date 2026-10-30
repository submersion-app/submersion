import 'package:flutter/material.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// "Copy to {account}" with Change, or "No copy off this device" with
/// Choose an account (spec section 8.2). The sheet offers every account
/// sync could use, plus no copy at all.
class BackupCopyRow extends ConsumerWidget {
  const BackupCopyRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(backupCopyTargetProvider);
    final target = async.value;
    if (target == null) {
      return ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: Text(
          async.hasError
              ? l10n.settings_connectedAccounts_loadError
              : l10n.settings_data_status_checking,
        ),
      );
    }
    // hasAccount: whether the copy names an account (Change) or not
    // (Choose an account).
    final (icon, title, detail, hasAccount) = switch (target) {
      CopyFollowsSync(group: final g?) => (
        accountKindIcon(g.kind),
        l10n.settings_backups_copyTo(g.label),
        l10n.settings_backups_copySameAsSync,
        true,
      ),
      CopyToAccount(:final group, :final row) => (
        accountKindIcon(group.kind),
        l10n.settings_backups_copyTo(group.label),
        accountStateText(l10n, group.statusOf(row.id) ?? group.status),
        true,
      ),
      CopyAccountGone() => (
        Icons.cloud_off_outlined,
        l10n.settings_backups_copyAccountGone,
        null,
        false,
      ),
      CopyFollowsSync() || NoCopy() => (
        Icons.cloud_off_outlined,
        l10n.settings_backups_noCopy,
        null,
        false,
      ),
    };
    return ListTile(
      key: const Key('backup-copy'),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail != null) Text(detail),
          TileSubtitleAction(
            actionKey: const Key('backup-copy-change'),
            label: hasAccount
                ? l10n.settings_sync_change
                : l10n.settings_backups_chooseAccount,
            onPressed: () => _change(context, ref, target),
          ),
        ],
      ),
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    BackupCopyTarget current,
  ) async {
    final l10n = context.l10n;
    final List<AccountGroup> groups;
    try {
      groups = await ref.read(accountGroupsProvider.future);
    } on Object {
      return;
    }
    if (!context.mounted) return;
    final choice = await showAccountOrNoneSheet(
      context,
      noneLabel: l10n.settings_backups_noCopy,
      noneSelected:
          current is NoCopy ||
          (current is CopyFollowsSync && current.group == null),
      allowedKinds: syncAccountKinds,
      currentKey: switch (current) {
        CopyFollowsSync(:final group) => group?.key,
        CopyToAccount(:final group) => group.key,
        _ => null,
      },
    );
    if (choice == null || !context.mounted) return;
    final applied = await applyBackupCopyChoice(
      ref,
      choice,
      syncGroup: groups.syncing,
    );
    // No keys for the server here, or the keychain or roster refused: the
    // copy stays where it was, and the diver hears the one step that fixes
    // the common case.
    if (!applied && choice is ChoseAccount && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settings_accounts_signInTo(choice.group.label)),
        ),
      );
    }
  }
}

/// Writes where the backup copy goes for [choice]: no copy, the account
/// sync uses ([syncGroup], so the copy follows sync), or any other account,
/// which pins the copy to it. False when an own server's row could not be
/// made here (no keys, or the keychain or roster refused); nothing changes
/// then.
Future<bool> applyBackupCopyChoice(
  WidgetRef ref,
  AccountSheetChoice choice, {
  AccountGroup? syncGroup,
}) async {
  final backup = ref.read(backupSettingsProvider.notifier);
  switch (choice) {
    case ChoseNone():
      await backup.setNoCopy();
    case ChoseAccount(:final group) when group.key == syncGroup?.key:
      await backup.setCopyFollowsSync();
    case ChoseAccount(:final group):
      final ConnectedAccount row;
      try {
        row = await _syncRowOf(ref, group);
      } on Object {
        return false;
      }
      await backup.setCopyTo(row);
  }
  return true;
}

/// The row the copy goes through: an own server's sync-folder row, created
/// with the account's keys when it has none yet (spec section 12), else the
/// account's own row.
Future<ConnectedAccount> _syncRowOf(WidgetRef ref, AccountGroup group) async {
  if (group.kind == AccountKind.s3 || group.kind == AccountKind.webdav) {
    return ref
        .read(accountGroupServiceProvider)
        .ensureRole(group, AccountRole.sync);
  }
  return group.rowFor(AccountRole.sync) ?? group.rows.first;
}
