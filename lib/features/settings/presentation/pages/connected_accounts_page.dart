import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The one place to sign in (spec section 7.6): every account the diver has,
/// grouped by server, with its sign-in state on this device and what it is
/// used for here. Tapping an account opens its detail view; "Add account"
/// opens the account sheet's add section.
class ConnectedAccountsPage extends ConsumerWidget {
  const ConnectedAccountsPage({super.key});

  /// Where an account's detail view lives: keyed by one of its roster rows,
  /// whose id is a path-safe UUID (the group key holds slashes).
  static String detailRoute(String accountId) =>
      '/settings/connected-accounts/$accountId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(accountGroupsProvider);
    Future<void> add() => showAccountSheet(context, addOnly: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_connectedAccounts_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.settings_accounts_add,
            onPressed: add,
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.settings_connectedAccounts_loadError)),
        data: (groups) => groups.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.settings_connectedAccounts_empty,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l10n.settings_accounts_add),
                        onPressed: add,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                children: [
                  for (final group in groups)
                    AccountGroupTile(
                      group: group,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.pushSettingsPage(
                        detailRoute(group.rows.first.id),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
