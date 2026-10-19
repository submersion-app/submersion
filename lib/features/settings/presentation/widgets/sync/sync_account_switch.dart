import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_provider_authenticate.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized connection-failure message for a cloud provider. For iCloud the
/// wording reflects the real [iCloudAvailability] state; other providers (and a
/// genuinely-available iCloud that still failed) get the generic message.
///
/// Pure (no `BuildContext`/`ref`) so it is unit-testable on any host.
@visibleForTesting
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
        break; // genuine failure despite availability — use the generic message
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
@visibleForTesting
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

/// Points sync at [provider] and authenticates it (today's provider tile
/// tap). The caller has already explained a switch and recorded the
/// departure from the old backend (the account sheet asks inside itself).
Future<void> selectProvider(
  BuildContext context,
  WidgetRef ref,
  CloudProviderType provider,
) async {
  // Set the provider first so cloudStorageProviderProvider returns the
  // correct instance.
  ref.read(selectedCloudProviderTypeProvider.notifier).state = provider;
  final cloudProvider = ref.read(cloudStorageProviderProvider);
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
    await authenticateWithBrowserWait(context, cloudProvider, provider);
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
    await ref.read(syncInitializerProvider).saveProvider(provider);
    ref.read(syncStateProvider.notifier).refreshState();
  } on CloudAuthCancelled {
    // The user backed out of the browser sign-in deliberately. Clear the
    // half-made selection, but do not dress a decision up as a failure.
    ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
  } catch (e) {
    ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
    if (context.mounted) {
      final iCloudAvailability = provider == CloudProviderType.icloud
          ? ref.read(iCloudAvailabilityProvider).value
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
AccountGroup? currentSyncGroup(List<AccountGroup> groups) => groups
    .where((g) => g.usages.any((u) => u.kind == AccountUsageKind.databaseSync))
    .firstOrNull;

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
  if (current != null && current.key == group.key) return;
  // An own server takes sync through its sync-role row; resolve it before
  // anything is recorded, so an account with no keys here changes nothing.
  ConnectedAccount? syncRow;
  if (group.isOwnServer) {
    try {
      syncRow = await ref
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
  // Recorded before the switch, while the provider still names the old
  // backend.
  final oldProvider = ref.read(cloudStorageProviderProvider);
  if (current != null &&
      oldProvider != null &&
      ref.read(syncStateProvider).lastSync != null) {
    await ref
        .read(syncStateProvider.notifier)
        .recordBackendDeparture(
          oldProvider: oldProvider,
          toProviderId: type.name,
          toProviderName: group.label,
        );
  }
  if (!context.mounted) return;
  if (syncRow != null) {
    await switchSyncToRow(context, ref, syncRow);
    return;
  }
  await selectProvider(context, ref, type);
}

/// Points sync at an own server's row [row]: its stored config becomes the
/// sync settings (the legacy store sync still reads), then today's provider
/// selection runs, as the S3 and WebDAV settings pages did on save.
/// Takes sync off an account that is being signed out or removed, so
/// nothing brings it back: the sync selection and its metadata are cleared
/// (and a Dropbox legacy key, by the sync sign-out), an S3 sync account's
/// legacy settings go too (the account derivation would mirror them back),
/// and cloud backups, which ride on sync, stop. WebDAV's adapter clears its
/// own legacy settings on sign-out.
Future<void> leaveSyncForAccount(WidgetRef ref, AccountKind kind) async {
  await ref.read(syncStateProvider.notifier).signOut();
  if (kind == AccountKind.s3) {
    await ref.read(s3StorageProviderInstanceProvider).signOut();
  }
  await ref.read(backupSettingsProvider.notifier).disableCloudBackup();
}

Future<void> switchSyncToRow(
  BuildContext context,
  WidgetRef ref,
  ConnectedAccount row,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final service = ref.read(accountGroupServiceProvider);
  switch (row.kind) {
    case AccountKind.s3:
      final config = await service.storedS3ForRow(row.id);
      if (config == null) {
        if (context.mounted) _noConfig(context);
        return;
      }
      await ref.read(s3StorageProviderInstanceProvider).saveConfig(config);
      container.invalidate(s3ConfigProvider);
    case AccountKind.webdav:
      final config = await service.storedWebDavForRow(row.id);
      if (config == null) {
        if (context.mounted) _noConfig(context);
        return;
      }
      await ref.read(webdavStorageProviderInstanceProvider).saveConfig(config);
      container.invalidate(webdavConfigProvider);
    default:
      return;
  }
  if (!context.mounted) return;
  // Persist the row first: the sync account derivation prefers the persisted
  // account of a kind, so selecting S3 while it still names the old S3 row
  // would mirror the new settings onto the old account.
  await ref
      .read(syncRepositoryProvider)
      .setSyncAccount(
        accountId: row.id,
        providerType: row.kind.cloudProviderType!,
      );
  if (!context.mounted) return;
  await selectProvider(context, ref, row.kind.cloudProviderType!);
  // Re-derive the sync account so its per-account credential mirror picks
  // up the new config; editing while already on the kind does not re-fire
  // the provider-type change.
  container
    ..invalidate(selectedSyncAccountProvider)
    ..invalidate(connectedAccountUsageProvider)
    ..invalidate(accountGroupsProvider)
    ..invalidate(pendingSetupItemsProvider);
  await container.read(selectedSyncAccountProvider.future);
}

/// Says the chosen server's settings could not be read on this device.
void _noConfig(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.settings_s3Config_error_secureStorage)),
  );
}
