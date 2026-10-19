import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/webdav_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

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

/// The diver's accounts: roster rows grouped by server, each with its
/// sign-in state and what it is used for on this device (issue #3482).
///
/// Probes every row (keychain, provider sessions), so only the pages that
/// show accounts read it; the Settings > Data page never does.
final accountGroupsProvider = FutureProvider.autoDispose<List<AccountGroup>>((
  ref,
) async {
  final withStatus = await ref.watch(
    connectedAccountsWithStatusProvider.future,
  );
  final usage = await ref.watch(connectedAccountUsageProvider.future);
  final registry = ref.watch(accountProviderRegistryProvider);
  final s3 = registry.capabilityFor<S3AccountAdapter>(AccountKind.s3);
  final webdav = registry.capabilityFor<WebDavAccountAdapter>(
    AccountKind.webdav,
  );
  // Rows the roster cannot place yet: this device's own stored config tells
  // which server they are on.
  final local = <String, AccountLocation>{};
  await Future.wait([
    for (final (account, _) in withStatus)
      if (account.location == null)
        () async {
          final location = switch (account.kind) {
            AccountKind.s3 => switch (await s3?.loadConfig(account)) {
              final c? => S3AccountLocation.fromConfig(c),
              null => null,
            },
            AccountKind.webdav => switch (await webdav?.loadConfig(account)) {
              final c? => WebDavAccountLocation.fromConfig(c),
              null => null,
            },
            _ => null,
          };
          if (location != null) local[account.id] = location;
        }(),
  ]);
  return groupAccounts(
    rows: [for (final (account, _) in withStatus) account],
    statusById: {
      for (final (account, status) in withStatus) account.id: status,
    },
    localLocationById: local,
    usagesOf: usage.usagesOf,
  );
});

/// A kind the diver can add here, in the order the account sheet lists them
/// (spec section 7.4). S3 and WebDAV are one entry, "My own server".
enum AccountKindOffer { icloud, googleDrive, dropbox, ownServer }

/// The kinds this platform and build can sign in to, gated exactly as the
/// sync page gates its providers today.
final offerableAccountKindsProvider =
    Provider.autoDispose<List<AccountKindOffer>>((ref) {
      final icloud = ref.watch(iCloudAvailabilityProvider).value;
      return [
        if (ref.watch(isApplePlatformProvider) &&
            icloud != null &&
            icloud != ICloudAvailability.unsupported)
          AccountKindOffer.icloud,
        if (ref.watch(googleDriveAvailableProvider).value ?? false)
          AccountKindOffer.googleDrive,
        if (ref.watch(dropboxConfiguredProvider)) AccountKindOffer.dropbox,
        AccountKindOffer.ownServer,
      ];
    });

/// The kind an offer adds; own servers pick S3 or WebDAV in their form.
AccountKind? kindOfOffer(AccountKindOffer offer) => switch (offer) {
  AccountKindOffer.icloud => AccountKind.icloud,
  AccountKindOffer.googleDrive => AccountKind.googledrive,
  AccountKindOffer.dropbox => AccountKind.dropbox,
  AccountKindOffer.ownServer => null,
};
