import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/pages/git_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_provider_authenticate.dart';
import 'package:submersion/features/settings/presentation/widgets/dropbox_connect_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(OwnServerForm);

/// Whether this build can run [kind]'s sign-in at all: one with no Google
/// client, or no Dropbox app key, cannot, and offers none (the account page
/// applies the same rule to Sign in again). [read] is a container's or a
/// ref's.
Future<bool> canSignInOnThisBuild(
  T Function<T>(ProviderListenable<T>) read,
  AccountKind kind,
) async => switch (kind) {
  AccountKind.googledrive => await read(googleDriveAvailableProvider.future),
  AccountKind.dropbox => read(dropboxConfiguredProvider),
  _ => true,
};

/// Runs [group]'s own sign-in on this device ("Sign in again", spec section
/// 7.6): Google and Dropbox their OAuth flows, an own server its form with
/// only the secret to type. iCloud has none (the Apple ID manages it) and
/// returns false. True when the account is signed in afterwards.
///
/// With [expectedAccount], a Google or Dropbox sign-in to another account is
/// refused before anything of it is kept: false, with the account it was
/// handed to [onDifferentAccount] (issue #3811).
Future<bool> signInToGroup(
  BuildContext context,
  WidgetRef ref,
  AccountGroup group, {
  WebDavCheck? webdavCheck,
  String? expectedAccount,
  ValueChanged<String>? onDifferentAccount,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final bool ok;
  switch (group.kind) {
    case AccountKind.googledrive:
      ok = await _signInGoogle(
        context,
        ref,
        expectedAccount: expectedAccount,
        onDifferentAccount: onDifferentAccount,
      );
      if (ok) {
        await _recordIdentity(
          container,
          group.rows.first,
          AccountKind.googledrive,
        );
      }
    case AccountKind.dropbox:
      ok = await _signInDropbox(
        context,
        group.rows.first.id,
        expectedAccount: expectedAccount,
        onDifferentAccount: onDifferentAccount,
      );
      if (ok) {
        await _recordIdentity(container, group.rows.first, AccountKind.dropbox);
      }
    case AccountKind.s3 || AccountKind.webdav:
      ok =
          await showOwnServerPage(
            context,
            existing: group,
            webdavCheck: webdavCheck,
          ) !=
          null;
      // Sync reads the legacy settings, which only the switch rewrites; only
      // for the row this device already syncs through, never a server that
      // merely has a default sync folder.
      final syncRow = group.syncRowHere;
      if (ok && syncRow != null && context.mounted) {
        await switchSyncToRow(context, ref, syncRow);
      }
    case AccountKind.git:
      final saved = await showGitAccountPage(context, existing: group);
      // Another repository or branch is saved as another account: this one
      // still has no keys here, so it is not signed in, and the new one is
      // listed for the diver to pick.
      ok = saved != null && saved.id == group.rows.first.id;
      if (saved != null && !ok) _refresh(container);
      // As for an own server, only when this device syncs through it.
      final syncRow = group.syncRowHere;
      if (ok && syncRow != null && context.mounted) {
        await switchSyncToRow(context, ref, syncRow);
      }
    case AccountKind.icloud || AccountKind.adobeLightroom:
      ok = false;
  }
  if (ok) {
    _refresh(container);
    await _clearBackupSignInNeed(container, group);
    await _refreshSyncAfterSignIn(container, group);
  }
  return ok;
}

/// The stored reason a backup copy failed no longer holds once its account
/// is signed in, from wherever. Best effort: a sign-in has already succeeded,
/// and the next backup overwrites the flag anyway.
Future<void> _clearBackupSignInNeed(
  ProviderContainer container,
  AccountGroup group,
) async {
  const copyUses = {AccountUsageKind.databaseSync, AccountUsageKind.backupCopy};
  if (!group.usages.any((u) => copyUses.contains(u.kind))) return;
  try {
    // Before the target, which probes every account.
    if (!container.read(backupSettingsProvider).lastCloudCopyNeedsSignIn) {
      return;
    }
    final target = await container.read(backupCopyTargetProvider.future);
    if (backupCopyGroupOf(target)?.key != group.key) return;
    await container
        .read(backupSettingsProvider.notifier)
        .clearCloudCopyNeedsSignIn();
  } catch (e, stack) {
    _log.warning(
      'Could not clear the backup sign-in flag',
      error: e,
      stackTrace: stack,
    );
  }
}

/// What sync knows about signing in, which Data health reads: the failure on
/// record, when it is this account's (sync's provider holds only one), and
/// whether it is signed in. Left alone during a sync, whose status a refresh
/// would overwrite.
Future<void> _refreshSyncAfterSignIn(
  ProviderContainer container,
  AccountGroup group,
) async {
  if (group.usages.any((u) => u.kind == AccountUsageKind.databaseSync)) {
    await container
        .read(syncFailureProvider.notifier)
        .clearFor(container.read(cloudStorageProviderProvider)?.providerId);
  }
  if (container.read(isSyncingProvider)) return;
  await container.read(syncStateProvider.notifier).refreshState();
}

/// Adds an account of [offer]'s kind (the account sheet's "Add an account"):
/// signs in, then records the roster row. Returns the row, or null when the
/// diver cancelled or the sign-in failed.
Future<ConnectedAccount?> addAccountRow(
  BuildContext context,
  WidgetRef ref,
  AccountKindOffer offer, {
  Set<AccountKind> kinds = const {AccountKind.s3, AccountKind.webdav},
  WebDavCheck? webdavCheck,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = context.l10n;
  final accounts = ref.read(connectedAccountsRepositoryProvider);
  Future<ConnectedAccount> ensure(AccountKind kind, String label) => accounts
      .ensure(kind: kind, naturalKey: naturalKeyForKind(kind)!, label: label);

  ConnectedAccount? row;
  switch (offer) {
    case AccountKindOffer.googleDrive:
      if (await _signInGoogle(context, ref)) {
        row = await ensure(
          AccountKind.googledrive,
          l10n.settings_cloudSync_provider_googleDrive,
        );
        await _recordIdentity(container, row, AccountKind.googledrive);
      }
    case AccountKindOffer.dropbox:
      final kept = await _connectDropbox(context);
      if (kept) {
        row = await ensure(
          AccountKind.dropbox,
          l10n.settings_cloudSync_provider_dropbox_title,
        );
        await container
            .read(accountCredentialsStoreProvider)
            .rekeyFromLegacy(
              legacyKey: DropboxAuthStore.storageKey,
              accountId: row.id,
              overwrite: true,
            );
        await _recordIdentity(container, row, AccountKind.dropbox);
      }
    case AccountKindOffer.icloud:
      final availability = await ref.read(iCloudAvailabilityProvider.future);
      if (availability == ICloudAvailability.available) {
        row = await ensure(
          AccountKind.icloud,
          l10n.settings_cloudSync_provider_icloud,
        );
      } else if (context.mounted) {
        // The message for the state iCloud is in: signed out, unsupported,
        // or not reachable just now.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              connectionErrorMessage(
                l10n,
                CloudProviderType.icloud,
                availability,
                l10n.settings_cloudSync_provider_icloud,
                '',
              ),
            ),
          ),
        );
      }
    case AccountKindOffer.ownServer:
      if (!context.mounted) return null;
      row = await showOwnServerPage(
        context,
        kinds: kinds,
        webdavCheck: webdavCheck,
      );
    case AccountKindOffer.git:
      if (!context.mounted) return null;
      row = await showGitAccountPage(context);
  }
  if (row != null) _refresh(container);
  return row;
}

/// Records which account the diver signed in to (the Google address, the
/// Dropbox account), shown under the account's name as the provider tiles
/// showed it, so two Google accounts can be told apart. Best effort.
///
/// Takes the container, as the Dropbox helpers do: the widget that started a
/// sign-in can be gone by the time it finishes, and with it its WidgetRef.
Future<void> _recordIdentity(
  ProviderContainer container,
  ConnectedAccount row,
  AccountKind kind,
) async {
  try {
    final provider = kind == AccountKind.googledrive
        ? container.read(
            cloudStorageProviderForProvider(CloudProviderType.googledrive),
          )
        : container.read(dropboxStorageProviderInstanceProvider);
    final email = (await provider.getUserEmail())?.trim();
    if (email == null || email.isEmpty || email == row.accountIdentifier) {
      return;
    }
    await container
        .read(connectedAccountsRepositoryProvider)
        .updateLabels(row.id, accountIdentifier: email);
  } catch (e, stack) {
    _log.warning(
      'Could not read the signed-in account',
      error: e,
      stackTrace: stack,
    );
  }
}

Future<bool> _signInGoogle(
  BuildContext context,
  WidgetRef ref, {
  String? expectedAccount,
  ValueChanged<String>? onDifferentAccount,
}) async {
  final provider = ref.read(
    cloudStorageProviderForProvider(CloudProviderType.googledrive),
  );
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  try {
    await authenticateWithBrowserWait(
      context,
      provider,
      CloudProviderType.googledrive,
      // `is` rather than a cast: tests stand in other providers here.
      signIn: provider is GoogleDriveStorageProvider
          ? () => provider.authenticateAs(expectedAccount)
          : null,
    );
    return true;
  } on CloudAuthCancelled {
    return false;
  } on CloudAccountMismatchException catch (e) {
    onDifferentAccount?.call(e.signedInAs);
    return false;
  } catch (e, stack) {
    _log.warning('Google sign-in failed', error: e, stackTrace: stack);
    // Said, as the provider tile said it: a failed sign-in must not look
    // like nothing happened.
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          connectionErrorMessage(
            l10n,
            CloudProviderType.googledrive,
            null,
            provider.providerName,
            errorDisplayText(e),
          ),
        ),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
}

Future<bool> _connectDropbox(
  BuildContext context, {
  String? expectedAccount,
  ValueChanged<String>? onDifferentAccount,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final connected = await showDialog<bool>(
    context: context,
    builder: (_) => DropboxConnectDialog(
      provider: container.read(dropboxStorageProviderInstanceProvider),
      expectedAccount: expectedAccount,
      onDifferentAccount: onDifferentAccount,
    ),
  );
  container.invalidate(dropboxAuthDataProvider);
  return connected == true;
}

Future<bool> _signInDropbox(
  BuildContext context,
  String accountId, {
  String? expectedAccount,
  ValueChanged<String>? onDifferentAccount,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final connected = await _connectDropbox(
    context,
    expectedAccount: expectedAccount,
    onDifferentAccount: onDifferentAccount,
  );
  if (!connected) return false;
  await container
      .read(accountCredentialsStoreProvider)
      .rekeyFromLegacy(
        legacyKey: DropboxAuthStore.storageKey,
        accountId: accountId,
        overwrite: true,
      );
  return true;
}

void _refresh(ProviderContainer container) =>
    refreshAccountState(container.invalidate);
