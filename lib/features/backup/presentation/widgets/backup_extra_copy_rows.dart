import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/backup/domain/entities/backup_copy_account.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_row.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// Kinds signed in once per device: a second account of one cannot hold
/// its own session, so it is never a second destination.
const _oneSessionKinds = {AccountKind.googledrive, AccountKind.icloud};

/// "Also copy to {account}" for each account a backup is also copied to,
/// then "Copy to another account too" (issue #3782). Shown below the main
/// copy's row, and only while the main copy names an account: the extra
/// copies ride on it.
class BackupExtraCopyRows extends ConsumerWidget {
  const BackupExtraCopyRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(backupCopyTargetProvider).value;
    final main = backupCopyGroupOf(target);
    if (main == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final settings = ref.watch(backupSettingsProvider);
    final groups = ref.watch(accountGroupsProvider).value;
    final missed = settings.lastExtraCopyMissingIds.toSet();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final account in settings.extraCopyAccounts)
          // An account the main copy now goes to (sync moved onto it) gets
          // no second copy, so it is not listed as one.
          if (groups?.holding(account.accountId)?.key != main.key)
            _ExtraCopyTile(
              account: account,
              group: groups?.holding(account.accountId),
              loading: groups == null,
              missed: missed.contains(account.accountId),
            ),
        ListTile(
          key: const Key('backup-extra-copy-add'),
          leading: const Icon(Icons.add),
          title: Text(l10n.settings_backups_addCopyAccount),
          onTap: () => _add(context, ref, target!),
        ),
      ],
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    BackupCopyTarget target,
  ) async {
    final l10n = context.l10n;
    final List<AccountGroup> groups;
    try {
      groups = await ref.read(accountGroupsProvider.future);
    } on Object {
      if (context.mounted) showAccountsLoadFailed(context, ref);
      return;
    }
    if (!context.mounted) return;
    final extras = ref.read(backupSettingsProvider).extraCopyAccounts;
    final main = backupCopyGroupOf(target);
    final used = [?main, for (final a in extras) ?groups.holding(a.accountId)];
    final usedKeys = {for (final g in used) g.key};
    final usedKinds = {
      ?main?.kind,
      for (final a in extras) a.kind,
    }.intersection(_oneSessionKinds);
    final group = await showAccountSheet(
      context,
      allowedKinds: syncAccountKinds.difference(usedKinds),
      excludedKeys: usedKeys,
    );
    // An account added afresh in the sheet may be one already in use.
    if (group == null || usedKeys.contains(group.key) || !context.mounted) {
      return;
    }
    try {
      final row = await backupCopyRowOf(ref, group);
      await ref.read(backupSettingsProvider.notifier).addExtraCopyAccount(row);
    } on Object {
      // No keys for the server here, or the keychain or roster refused.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settings_accounts_signInTo(group.label))),
      );
    }
  }
}

class _ExtraCopyTile extends ConsumerWidget {
  const _ExtraCopyTile({
    required this.account,
    required this.group,
    required this.loading,
    required this.missed,
  });

  final BackupCopyAccount account;

  /// Null while the accounts load, or once the roster lost this row.
  final AccountGroup? group;
  final bool loading;
  final bool missed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final group = this.group;
    final String title;
    final String? detail;
    if (group != null) {
      title = l10n.settings_backups_alsoCopyTo(group.label);
      detail = missed
          ? l10n.settings_backups_extraCopyMissed
          : accountStateText(
              l10n,
              group.statusOf(account.accountId) ?? group.status,
            );
    } else {
      title = loading
          ? l10n.settings_data_status_checking
          : l10n.settings_backups_copyAccountGone;
      detail = null;
    }
    final id = account.accountId;
    return ListTile(
      key: Key('backup-extra-copy-$id'),
      leading: Icon(
        group == null && !loading
            ? Icons.cloud_off_outlined
            : accountKindIcon(account.kind),
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail != null) Text(detail),
          TileSubtitleAction(
            actionKey: Key('backup-extra-copy-remove-$id'),
            label: l10n.common_action_remove,
            onPressed: () => ref
                .read(backupSettingsProvider.notifier)
                .removeExtraCopyAccount(id),
          ),
        ],
      ),
    );
  }
}
