import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/l10n/l10n_extension.dart';

/// The account roster with per-device sign-in status. Statuses are derived
/// live (keychain probe / session check); invalidate after any
/// connect/disconnect elsewhere.
final connectedAccountsWithStatusProvider =
    FutureProvider.autoDispose<List<(domain.ConnectedAccount, AccountStatus)>>((
      ref,
    ) async {
      final accounts = await ref
          .watch(connectedAccountsRepositoryProvider)
          .getAll();
      final registry = ref.watch(accountProviderRegistryProvider);
      // Status probes hit the keychain / provider sessions: run them
      // concurrently so one slow probe cannot serialize the page load.
      return Future.wait([
        for (final account in accounts)
          () async {
            final adapter = registry.capabilityFor<AccountProviderAdapter>(
              account.kind,
            );
            return (
              account,
              adapter == null
                  ? AccountStatus.unavailable
                  : await adapter.status(account),
            );
          }(),
      ]);
    });

/// Top-level roster of linked endpoints (program spec section 5): one place
/// to see every account, its per-device status, and the two scopes of
/// removal (this device's credentials vs the synced roster row).
class ConnectedAccountsPage extends ConsumerWidget {
  const ConnectedAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountsAsync = ref.watch(connectedAccountsWithStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_connectedAccounts_title)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.settings_connectedAccounts_loadError)),
        data: (accounts) => accounts.isEmpty
            ? Center(child: Text(l10n.settings_connectedAccounts_empty))
            : ListView(
                children: [
                  for (final (account, status) in accounts)
                    _AccountTile(account: account, status: status),
                ],
              ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.status});

  final domain.ConnectedAccount account;
  final AccountStatus status;

  IconData get _icon => switch (account.kind) {
    AccountKind.s3 => Icons.dns_outlined,
    AccountKind.dropbox => Icons.cloud_outlined,
    AccountKind.googledrive => Icons.add_to_drive_outlined,
    AccountKind.icloud => Icons.cloud_circle_outlined,
    AccountKind.adobeLightroom => Icons.photo_library_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final (statusText, statusColor) = switch (status) {
      AccountStatus.signedIn => (
        l10n.settings_connectedAccounts_status_signedIn,
        colorScheme.primary,
      ),
      AccountStatus.needsSignIn => (
        l10n.settings_connectedAccounts_status_needsSignIn,
        colorScheme.error,
      ),
      AccountStatus.unavailable => (
        l10n.settings_connectedAccounts_status_unavailable,
        colorScheme.onSurfaceVariant,
      ),
    };

    return ListTile(
      leading: Icon(_icon),
      title: Text(account.label),
      subtitle: Text(
        account.accountIdentifier == null
            ? statusText
            : '${account.accountIdentifier} - $statusText',
        style: TextStyle(color: statusColor),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (choice) async {
          final registry = ref.read(accountProviderRegistryProvider);
          final adapter = registry.capabilityFor<AccountProviderAdapter>(
            account.kind,
          );
          switch (choice) {
            case 'signOut':
              await adapter?.disconnect(account);
            case 'remove':
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    l10n.settings_connectedAccounts_removeConfirmTitle,
                  ),
                  content: Text(
                    l10n.settings_connectedAccounts_removeConfirmBody,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        MaterialLocalizations.of(ctx).cancelButtonLabel,
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        l10n.settings_connectedAccounts_removeFromLibrary,
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await adapter?.disconnect(account);
              await ref
                  .read(connectedAccountsRepositoryProvider)
                  .delete(account.id);
          }
          ref.invalidate(connectedAccountsWithStatusProvider);
        },
        itemBuilder: (_) => [
          if (status == AccountStatus.signedIn)
            PopupMenuItem(
              value: 'signOut',
              child: Text(l10n.settings_connectedAccounts_disconnectDevice),
            ),
          PopupMenuItem(
            value: 'remove',
            child: Text(l10n.settings_connectedAccounts_removeFromLibrary),
          ),
        ],
      ),
    );
  }
}
