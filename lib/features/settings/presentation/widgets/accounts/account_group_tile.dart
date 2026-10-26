import 'package:flutter/material.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

IconData accountKindIcon(AccountKind kind) => switch (kind) {
  AccountKind.s3 => Icons.dns_outlined,
  AccountKind.webdav => Icons.folder_shared_outlined,
  AccountKind.git => Icons.commit,
  AccountKind.dropbox => Icons.cloud_outlined,
  AccountKind.googledrive => Icons.add_to_drive_outlined,
  AccountKind.icloud => Icons.cloud_circle_outlined,
  AccountKind.adobeLightroom => Icons.photo_library_outlined,
};

/// The name a feature that uses an account is shown under, in the words of
/// spec section 4.
String accountUsageName(AppLocalizations l10n, AccountUsage usage) =>
    switch (usage.kind) {
      AccountUsageKind.databaseSync => l10n.settings_accounts_usage_sync,
      AccountUsageKind.mediaStorage => l10n.settings_accounts_usage_photos,
      AccountUsageKind.sharedLibrary =>
        l10n.settings_connectedAccounts_usage_sharedLibrary(
          usage.libraryName ?? '',
        ),
      AccountUsageKind.lightroom =>
        l10n.settings_connectedAccounts_usage_lightroom,
      AccountUsageKind.backupCopy => l10n.settings_accounts_usage_backups,
    };

/// The sign-in state of an account on this device, as words.
String accountStateText(AppLocalizations l10n, AccountStatus status) =>
    switch (status) {
      AccountStatus.signedIn => l10n.settings_connectedAccounts_status_signedIn,
      AccountStatus.needsSignIn => l10n.settings_accounts_state_notSignedIn,
      AccountStatus.unavailable =>
        l10n.settings_connectedAccounts_status_unavailable,
    };

/// One account: icon, label, sign-in state and what it is used for here.
/// [inSheet] words a signed-out account as an invitation to sign in.
class AccountGroupTile extends StatelessWidget {
  const AccountGroupTile({
    super.key,
    required this.group,
    this.selected = false,
    this.inSheet = false,
    this.onTap,
    this.trailing,
  });

  final AccountGroup group;
  final bool selected;
  final bool inSheet;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = inSheet && group.status == AccountStatus.needsSignIn
        ? l10n.settings_accounts_signInHere
        : accountStateText(l10n, group.status);
    final stateColor = switch (group.status) {
      AccountStatus.signedIn => colors.primary,
      AccountStatus.needsSignIn => colors.error,
      AccountStatus.unavailable => colors.onSurfaceVariant,
    };
    final identifier = group.identifier;
    final usages = group.usages;
    return ListTile(
      // In the sheet an account this device cannot use cannot be chosen; on
      // the accounts page it still opens, to read why or remove it.
      enabled: !inSheet || group.status != AccountStatus.unavailable,
      selected: selected,
      leading: Icon(accountKindIcon(group.kind)),
      title: Text(group.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The full address stays visible under a short name (#3522).
          if (group.address != group.label)
            Text(
              group.address,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          // On their own lines: no separator to translate or mirror.
          if (identifier != null) Text(identifier),
          Text(state, style: TextStyle(color: stateColor)),
          if (group.usagesKnown)
            Text(
              usages.isEmpty
                  ? (group.isOwnServer
                        ? l10n.settings_accounts_notUsedYet
                        : l10n.settings_connectedAccounts_usage_none)
                  : l10n.settings_connectedAccounts_usage_label(
                      usages.map((u) => accountUsageName(l10n, u)).join(', '),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: selected ? const Icon(Icons.check) : trailing,
      onTap: onTap,
    );
  }
}
