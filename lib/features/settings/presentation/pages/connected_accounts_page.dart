import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The account roster with per-device sign-in status. Statuses are derived
/// live (keychain probe / session check); invalidate after any
/// connect/disconnect elsewhere.
final connectedAccountsWithStatusProvider =
    FutureProvider.autoDispose<List<(domain.ConnectedAccount, AccountStatus)>>((
      ref,
    ) async {
      final repository = ref.watch(connectedAccountsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchAccountsChanges());
      final accounts = await repository.getAll();
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

/// What each account is used for on this device (issue #3388), from the
/// same [AccountUsageService] the pending-setup card routes with.
final connectedAccountUsageProvider =
    FutureProvider.autoDispose<AccountUsageSnapshot>((ref) async {
      // Re-read on any change to what the usages come from, the page stays
      // mounted under the Settings routes that make those changes: shared
      // libraries (table updates), the sync selection (setSyncAccount and
      // setCloudProvider notify the sync event bus) and the media store
      // attachment (every attach change fires markerMismatchChanges).
      final libraries = ref.watch(sharedLibraryStoreProvider);
      ref
        ..invalidateSelfWhen(libraries.watchLibraries())
        ..invalidateSelfWhen(SyncEventBus.changes)
        ..invalidateSelfWhen(MediaStoreAttachState.markerMismatchChanges);
      return AccountUsageService(
        attachState: MediaStoreAttachState(
          prefs: ref.watch(sharedPreferencesProvider),
        ),
        libraries: libraries,
      ).load();
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
    // Null while loading: rows show without the usage line rather than
    // holding the whole list back.
    final usage = ref.watch(connectedAccountUsageProvider).value;

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
                    _AccountTile(
                      account: account,
                      status: status,
                      usages: usage?.usagesOf(account),
                    ),
                ],
              ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    required this.account,
    required this.status,
    required this.usages,
  });

  final domain.ConnectedAccount account;
  final AccountStatus status;

  /// What uses the account on this device; null while still loading.
  final List<AccountUsage>? usages;

  IconData get _icon => switch (account.kind) {
    AccountKind.s3 => Icons.dns_outlined,
    AccountKind.webdav => Icons.folder_shared_outlined,
    AccountKind.dropbox => Icons.cloud_outlined,
    AccountKind.googledrive => Icons.add_to_drive_outlined,
    AccountKind.icloud => Icons.cloud_circle_outlined,
    AccountKind.adobeLightroom => Icons.photo_library_outlined,
  };

  /// This account's usages, read at tap time rather than from the build: a
  /// tap before the usage load finished would otherwise skip the warning.
  /// Null when the read failed: the caller confirms conservatively rather
  /// than treating an unknown as unused.
  Future<List<AccountUsage>?> _usagesAtTap(ProviderContainer container) async {
    try {
      return (await container.read(
        connectedAccountUsageProvider.future,
      )).usagesOf(account);
    } catch (e, stackTrace) {
      _log.error(
        'Could not read account usage',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
    final usages = this.usages;

    return ListTile(
      leading: Icon(_icon),
      title: Text(account.label),
      isThreeLine: usages != null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            account.accountIdentifier == null
                ? statusText
                : '${account.accountIdentifier} - $statusText',
            style: TextStyle(color: statusColor),
          ),
          if (usages != null)
            Text(
              usages.isEmpty
                  ? l10n.settings_connectedAccounts_usage_none
                  : l10n.settings_connectedAccounts_usage_label(
                      usages.map((u) => usageName(l10n, u)).join(', '),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (choice) async {
          // Removing the row rebuilds the list and can dispose this tile
          // before the refresh below; the container outlives it.
          final container = ProviderScope.containerOf(context, listen: false);
          final registry = ref.read(accountProviderRegistryProvider);
          final adapter = registry.capabilityFor<AccountProviderAdapter>(
            account.kind,
          );
          final used = await _usagesAtTap(container);
          if (!context.mounted) return;
          switch (choice) {
            case 'signOut':
              // Known to be unused here: signing out breaks nothing, so it
              // acts at once, as it always has. Used, or unknown because
              // the read failed, asks first.
              if (used?.isEmpty != true &&
                  !await _confirm(
                    context,
                    title: l10n.settings_connectedAccounts_signOutConfirmTitle,
                    paragraphs: [
                      used == null
                          ? l10n.settings_connectedAccounts_usage_unknown
                          : l10n.settings_connectedAccounts_signOutConfirmBody(
                              account.label,
                            ),
                    ],
                    usages: used ?? const [],
                    action: l10n.settings_connectedAccounts_disconnectDevice,
                  )) {
                return;
              }
              await adapter?.disconnect(account);
            case 'remove':
              final confirmed = await _confirm(
                context,
                title: l10n.settings_connectedAccounts_removeConfirmTitle,
                paragraphs: [
                  l10n.settings_connectedAccounts_removeConfirmBody,
                  if (used == null)
                    l10n.settings_connectedAccounts_usage_unknown
                  else if (used.isNotEmpty)
                    l10n.settings_connectedAccounts_removeConfirmUsedHere,
                ],
                usages: used ?? const [],
                // The roster row goes from every device, and what other
                // devices use it for is not known here.
                footer:
                    l10n.settings_connectedAccounts_removeConfirmOtherDevices,
                action: l10n.settings_connectedAccounts_removeFromLibrary,
              );
              if (!confirmed) return;
              await adapter?.disconnect(account);
              await ref
                  .read(connectedAccountsRepositoryProvider)
                  .delete(account.id);
          }
          // A sign-out touches only the keychain, so nothing in the
          // database ticks; the setup items behind the Settings > Data rows
          // must recompute too.
          container
            ..invalidate(connectedAccountsWithStatusProvider)
            ..invalidate(connectedAccountUsageProvider)
            ..invalidate(pendingSetupItemsProvider);
          // Disconnecting the WebDAV sync account clears the sync settings
          // too; the Cloud Sync tile reads them through this provider.
          if (account.kind == AccountKind.webdav) {
            container.invalidate(webdavConfigProvider);
          }
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

final _log = LoggerService.forClass(ConnectedAccountsPage);

/// The name a usage is shown under, on the row and in the warnings.
String usageName(AppLocalizations l10n, AccountUsage usage) =>
    switch (usage.kind) {
      AccountUsageKind.databaseSync =>
        l10n.settings_connectedAccounts_usage_databaseSync,
      AccountUsageKind.mediaStorage =>
        l10n.settings_connectedAccounts_usage_mediaStorage,
      AccountUsageKind.sharedLibrary =>
        l10n.settings_connectedAccounts_usage_sharedLibrary(
          usage.libraryName ?? '',
        ),
      AccountUsageKind.lightroom =>
        l10n.settings_connectedAccounts_usage_lightroom,
    };

/// A confirmation naming the features [usages] lists, below [paragraphs]
/// and above [footer]. True only when the user picks [action].
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
  required List<AccountUsage> usages,
  required String action,
  String? footer,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, paragraph) in paragraphs.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: Text(paragraph),
              ),
            for (final usage in usages)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6),
                    const SizedBox(width: 8),
                    Expanded(child: Text(usageName(l10n, usage))),
                  ],
                ),
              ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(footer),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
