import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/logger_service.dart';
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
/// applies the same rule to Sign in again).
Future<bool> canSignInOnThisBuild(
  ProviderContainer container,
  AccountKind kind,
) async => switch (kind) {
  AccountKind.googledrive => await container.read(
    googleDriveAvailableProvider.future,
  ),
  AccountKind.dropbox => container.read(dropboxConfiguredProvider),
  _ => true,
};

/// Runs [group]'s own sign-in on this device ("Sign in again", spec section
/// 7.6): Google and Dropbox their OAuth flows, an own server its form with
/// only the secret to type. iCloud has none (the Apple ID manages it) and
/// returns false. True when the account is signed in afterwards.
Future<bool> signInToGroup(
  BuildContext context,
  WidgetRef ref,
  AccountGroup group, {
  WebDavCheck? webdavCheck,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final bool ok;
  switch (group.kind) {
    case AccountKind.googledrive:
      ok = await _signInGoogle(context, ref);
      if (ok) {
        await _recordIdentity(ref, group.rows.first, AccountKind.googledrive);
      }
    case AccountKind.dropbox:
      ok = await _signInDropbox(context, ref, group.rows.first.id);
      if (ok) await _recordIdentity(ref, group.rows.first, AccountKind.dropbox);
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
  if (ok) _refresh(container);
  return ok;
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
        await _recordIdentity(ref, row, AccountKind.googledrive);
      }
    case AccountKindOffer.dropbox:
      final kept = await _connectDropbox(context, ref);
      if (kept) {
        row = await ensure(
          AccountKind.dropbox,
          l10n.settings_cloudSync_provider_dropbox_title,
        );
        await ref
            .read(accountCredentialsStoreProvider)
            .rekeyFromLegacy(
              legacyKey: DropboxAuthStore.storageKey,
              accountId: row.id,
              overwrite: true,
            );
        await _recordIdentity(ref, row, AccountKind.dropbox);
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
Future<void> _recordIdentity(
  WidgetRef ref,
  ConnectedAccount row,
  AccountKind kind,
) async {
  try {
    final provider = kind == AccountKind.googledrive
        ? ref.read(
            cloudStorageProviderForProvider(CloudProviderType.googledrive),
          )
        : ref.read(dropboxStorageProviderInstanceProvider);
    final email = (await provider.getUserEmail())?.trim();
    if (email == null || email.isEmpty || email == row.accountIdentifier) {
      return;
    }
    await ref
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

Future<bool> _signInGoogle(BuildContext context, WidgetRef ref) async {
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
    );
    return true;
  } on CloudAuthCancelled {
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

Future<bool> _connectDropbox(BuildContext context, WidgetRef ref) async {
  final connected = await showDialog<bool>(
    context: context,
    builder: (_) => DropboxConnectDialog(
      provider: ref.read(dropboxStorageProviderInstanceProvider),
    ),
  );
  ref.invalidate(dropboxAuthDataProvider);
  return connected == true;
}

Future<bool> _signInDropbox(
  BuildContext context,
  WidgetRef ref,
  String accountId,
) async {
  if (!await _connectDropbox(context, ref)) return false;
  await ref
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
