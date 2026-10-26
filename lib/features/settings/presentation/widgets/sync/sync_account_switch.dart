import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/git_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_provider_authenticate.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('SyncAccountSwitch');

/// Localized connection-failure message for a cloud provider. For iCloud the
/// wording reflects the real [iCloudAvailability] state; other providers (and a
/// genuinely-available iCloud that still failed) get the generic message.
///
/// Pure (no `BuildContext`/`ref`) so it is unit-testable on any host.
String connectionErrorMessage(
  AppLocalizations l10n,
  CloudProviderType provider,
  ICloudAvailability? iCloudAvailability,
  String providerName,
  String error,
) {
  if (provider == CloudProviderType.icloud) {
    switch (iCloudAvailability) {
      case ICloudAvailability.unsupported:
        return l10n.settings_cloudSync_error_icloudUnsupported;
      case ICloudAvailability.signedOut:
        return l10n.settings_cloudSync_error_icloudSignedOut;
      case ICloudAvailability.unknown:
      case null:
        return l10n.settings_cloudSync_error_icloudUnknown;
      case ICloudAvailability.available:
        break; // a genuine failure despite availability: the generic message
    }
  }
  return l10n.settings_cloudSync_provider_connectionFailed(providerName, error);
}

/// Snackbar-safe text for a connection failure.
///
/// [CloudStorageException.displayMessage] exists for this: its `toString`
/// prefixes the class name, which reached users as "Google Drive connection
/// failed: CloudStorageException: ...". The cause is kept either way, since
/// that is where the actionable detail lives.
///
/// Pure (no `BuildContext`/`ref`) so it is unit-testable on any host.
String errorDisplayText(Object error) =>
    error is CloudStorageException ? error.displayMessage : error.toString();

/// Display name for a provider type, for dialogs and banners.
String providerDisplayName(BuildContext context, CloudProviderType type) {
  final l10n = context.l10n;
  return switch (type) {
    CloudProviderType.icloud => l10n.settings_cloudSync_provider_icloud,
    CloudProviderType.googledrive =>
      l10n.settings_cloudSync_provider_googleDrive,
    CloudProviderType.s3 => l10n.settings_cloudSync_provider_s3_title,
    CloudProviderType.dropbox => l10n.settings_cloudSync_provider_dropbox_title,
    CloudProviderType.webdav => l10n.settings_cloudSync_provider_webdav_title,
    CloudProviderType.git => l10n.settings_cloudSync_provider_git_title,
  };
}

/// Maps a stored providerId back to a display name (for the cleanup banner,
/// which only has the id of the old backend).
String providerDisplayNameForId(BuildContext context, String providerId) {
  final type = CloudProviderType.values
      .where((t) => t.name == providerId)
      .firstOrNull;
  return type == null ? providerId : providerDisplayName(context, type);
}

/// Points sync at [provider] and authenticates it. The caller has already
/// explained a switch and recorded the departure from the old backend (the
/// account sheet asks inside itself). [signedIn] skips the sign-in when the
/// account sheet has just signed the account in, so the diver is not asked
/// twice.
///
/// Reads go through the container: the page or sheet that asked may close
/// while the sign-in runs, and the selection must still be saved.
Future<void> selectProvider(
  BuildContext context,
  WidgetRef ref,
  CloudProviderType provider, {
  bool signedIn = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // Set the provider first so cloudStorageProviderProvider returns the
  // correct instance.
  container.read(selectedCloudProviderTypeProvider.notifier).state = provider;
  final cloudProvider = container.read(cloudStorageProviderProvider);
  if (cloudProvider == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.settings_cloudSync_provider_initFailed(provider.name),
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    if (!signedIn) {
      await authenticateWithBrowserWait(context, cloudProvider, provider);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.settings_cloudSync_provider_connectedTo(
              cloudProvider.providerName,
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
    await container.read(syncInitializerProvider).saveProvider(provider);
    container.read(syncStateProvider.notifier).refreshState();
  } on CloudAuthCancelled {
    // The user backed out of the browser sign-in deliberately. Clear the
    // half-made selection, but do not dress a decision up as a failure.
    container.read(selectedCloudProviderTypeProvider.notifier).state = null;
  } catch (e) {
    container.read(selectedCloudProviderTypeProvider.notifier).state = null;
    if (context.mounted) {
      final iCloudAvailability = provider == CloudProviderType.icloud
          ? container.read(iCloudAvailabilityProvider).value
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connectionErrorMessage(
              context.l10n,
              provider,
              iCloudAvailability,
              cloudProvider.providerName,
              errorDisplayText(e),
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// The account sync uses on this device, or null.
AccountGroup? currentSyncGroup(List<AccountGroup> groups) => groups.syncing;

/// What choosing [choice] for sync will do, for the account sheet to show
/// before it returns: today's "Switch sync backend?" text when this device
/// has synced and [choice] is not the account sync already uses; null
/// otherwise, so choosing the current account asks nothing.
String? syncSwitchConsequence(
  BuildContext context,
  WidgetRef ref,
  AccountGroup choice, {
  AccountGroup? current,
}) {
  if (current == null || current.key == choice.key) return null;
  if (ref.read(syncStateProvider).lastSync == null) return null;
  return context.l10n.settings_cloudSync_switch_dialogContent(
    current.label,
    choice.label,
  );
}

/// Points sync at [group], chosen from the account sheet (which has already
/// shown [syncSwitchConsequence] when there was one). An own server without
/// a sync-role row gets one first, on the server's credentials.
Future<void> useAccountForSync(
  BuildContext context,
  WidgetRef ref,
  AccountGroup group, {
  AccountGroup? current,
}) async {
  final type = group.kind.cloudProviderType;
  if (type == null) return;
  // The current account again is a no-op, unless a failed or cancelled
  // sign-in left sync with no provider selected: then it selects again,
  // with no departure (nothing is left behind).
  final sameAccount = current != null && current.key == group.key;
  if (sameAccount && ref.read(selectedCloudProviderTypeProvider) != null) {
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  // An own server takes sync through its sync-role row; resolve it before
  // anything is recorded, so an account with no keys here changes nothing.
  // The folder this device last synced to comes first: after Stop syncing
  // its row has no usage left, and a custom folder ("dives/") has no
  // default name to be found by.
  ConnectedAccount? syncRow;
  if (group.kind == AccountKind.git) {
    // A Git account is one repository and branch: one row, sync's own,
    // which can take sync only with its keys here (checked, like an own
    // server's, before anything is recorded).
    final row = group.rows.first;
    if (await container.read(accountCredentialsStoreProvider).read(row.id) ==
        null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settings_accounts_signInTo(group.label)),
          ),
        );
      }
      return;
    }
    syncRow = row;
  } else if (group.isOwnServer) {
    try {
      syncRow =
          await _lastSyncedRowIn(container, group) ??
          await container
              .read(accountGroupServiceProvider)
              .ensureRole(group, AccountRole.sync);
    } on StateError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settings_accounts_signInTo(group.label)),
          ),
        );
      }
      return;
    }
  }
  if (!context.mounted) return;
  // Another account of the kind sync already uses (S3 bucket to S3 bucket):
  // everything the sync engine keys on the provider kind would carry over.
  final sameKind =
      current != null && !sameAccount && current.kind == group.kind;
  // Recorded before the switch, while the provider still names the old
  // backend.
  final oldProvider = ref.read(cloudStorageProviderProvider);
  if (current != null &&
      !sameAccount &&
      oldProvider != null &&
      ref.read(syncStateProvider).lastSync != null) {
    await ref
        .read(syncStateProvider.notifier)
        .recordBackendDeparture(
          oldProvider: oldProvider,
          // Devices still on the old account ignore a marker naming the kind
          // they are on; the destination account is named instead.
          toProviderId: sameKind
              ? '${type.name}:${(syncRow ?? group.rows.first).id}'
              : type.name,
          toProviderName: group.label,
        );
  }
  if (sameKind) {
    // The new account's first sync is first contact: the Combine check runs
    // and the old account's cursor is not reused. No cleanup is armed: it
    // would delete through the kind's one settings instance, which now
    // points at the new account.
    try {
      await container.read(establishedProviderStoreProvider).remove(type.name);
      await container.read(syncRepositoryProvider).retireCursor(type.name);
      await container.read(libraryMovedStoreProvider).clearPendingCleanup();
    } catch (e, st) {
      // The switch still goes ahead; the Combine check may then be skipped.
      _log.warning(
        'Could not reset first contact for $type',
        error: e,
        stackTrace: st,
      );
    }
  }
  if (!context.mounted) return;
  if (syncRow != null) {
    await switchSyncToRow(context, ref, syncRow);
    return;
  }
  // The sheet signs an account in before returning it; a Google account
  // that is signed in now must not ask for a second consent.
  await selectProvider(
    context,
    ref,
    type,
    signedIn:
        type == CloudProviderType.googledrive &&
        group.status == AccountStatus.signedIn,
  );
}

/// The row of [group] this device's sync settings still name (the folder it
/// last synced to), when this device holds that row's keys.
Future<ConnectedAccount?> _lastSyncedRowIn(
  ProviderContainer container,
  AccountGroup group,
) async {
  final service = container.read(accountGroupServiceProvider);
  final String? id;
  switch (group.kind) {
    case AccountKind.s3:
      final c = await container
          .read(s3StorageProviderInstanceProvider)
          .loadConfig();
      id = c == null
          ? null
          : accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(c));
    case AccountKind.webdav:
      final c = await container
          .read(webdavStorageProviderInstanceProvider)
          .loadConfig();
      id = c == null
          ? null
          : accountIdFor(
              kind: AccountKind.webdav,
              naturalKey: webdavNaturalKey(c),
            );
    default:
      return null;
  }
  final row = group.rows.firstWhereOrNull((r) => r.id == id);
  if (row == null) return null;
  final held = group.kind == AccountKind.s3
      ? await service.storedS3ForRow(row.id) != null
      : await service.storedWebDavForRow(row.id) != null;
  return held ? row : null;
}

/// Takes sync off the account this device syncs through, as it is signed
/// out or removed, so nothing brings it back: the sync selection and its
/// metadata are cleared (and a Dropbox legacy key, by the sync sign-out).
/// The S3 and WebDAV adapters clear their own legacy settings when they sign
/// the sync row out. The backup copy is the caller's to settle, since only
/// it knows whether the copy goes with the account
/// (`backupCopyGoesWith`).
///
/// Takes the container rather than a WidgetRef: the confirmation the diver
/// answered has closed, and the teardown must finish whatever the page does.
Future<void> leaveSyncForAccount(ProviderContainer container) async {
  await container.read(syncStateProvider.notifier).signOut();
}

/// Points sync at an own server's row [row]: its stored config becomes the
/// sync settings (the legacy store sync still reads) and the row becomes the
/// sync account.
///
/// On the kind sync already uses (a save of the sync account's details, or
/// one S3 account to another) nothing is signed in again, as the S3 and
/// WebDAV settings pages saved: the account is re-derived first, so nothing
/// can probe the previous row's cached provider. On another kind the
/// provider is selected as a tile tap did.
///
/// Every write goes through the container, with no early return between
/// them: the page or sheet that asked may close mid-switch, and settings
/// written without the account persisted would be mirrored onto the old row.
Future<void> switchSyncToRow(
  BuildContext context,
  WidgetRef ref,
  ConnectedAccount row,
) async {
  final type = row.kind.cloudProviderType;
  if (type == null) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final noConfig = context.l10n.settings_s3Config_error_secureStorage;
  final service = container.read(accountGroupServiceProvider);
  switch (row.kind) {
    case AccountKind.s3:
      final config = await service.storedS3ForRow(row.id);
      if (config == null) {
        messenger?.showSnackBar(SnackBar(content: Text(noConfig)));
        return;
      }
      await container
          .read(s3StorageProviderInstanceProvider)
          .saveConfig(config);
    case AccountKind.webdav:
      final config = await service.storedWebDavForRow(row.id);
      if (config == null) {
        messenger?.showSnackBar(SnackBar(content: Text(noConfig)));
        return;
      }
      await container
          .read(webdavStorageProviderInstanceProvider)
          .saveConfig(config);
      container.invalidate(webdavConfigProvider);
    case AccountKind.git:
      final config = decodeGitConfig(
        await container.read(accountCredentialsStoreProvider).read(row.id),
      );
      if (config == null) {
        messenger?.showSnackBar(SnackBar(content: Text(noConfig)));
        return;
      }
      await container
          .read(gitStorageProviderInstanceProvider)
          .saveConfig(config);
      container.invalidate(gitConfigProvider);
    default:
      return;
  }
  // Persist the row first: the sync account derivation prefers the persisted
  // account of a kind, so selecting S3 while it still names the old S3 row
  // would mirror the new settings onto the old account.
  await container
      .read(syncRepositoryProvider)
      .setSyncAccount(accountId: row.id, providerType: type);
  if (container.read(selectedCloudProviderTypeProvider) == type) {
    await _rederiveSyncAccount(container);
    await container.read(syncInitializerProvider).saveProvider(type);
    await container.read(syncStateProvider.notifier).refreshState();
    return;
  }
  if (context.mounted) await selectProvider(context, ref, type);
  await _rederiveSyncAccount(container);
}

/// Re-derives the sync account, so its per-account credential mirror and
/// the sync provider pick up the row just written.
Future<void> _rederiveSyncAccount(ProviderContainer container) async {
  container.invalidate(selectedSyncAccountProvider);
  refreshAccountState(container.invalidate);
  await container.read(selectedSyncAccountProvider.future);
}
