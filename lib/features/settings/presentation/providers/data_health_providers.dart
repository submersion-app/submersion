import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/data/data_facts_repository.dart';
import 'package:submersion/features/settings/domain/data_health/backup_health.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/media_health.dart';
import 'package:submersion/features/settings/domain/data_health/shared_library_health.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

// One health model behind the Settings > Data rows and the feature pages'
// marks (issues #3390, #3394, #4561), so the two can never disagree.

// What a feature reads as while its inputs load or fail to load.
const _librariesNotSetUp = FeatureHealth(
  feature: DataFeature.sharedLibraries,
  level: HealthLevel.notSetUp,
  reason: HealthReason.notSetUp,
);
const _mediaNotSetUp = FeatureHealth(
  feature: DataFeature.media,
  level: HealthLevel.notSetUp,
  reason: HealthReason.notSetUp,
);

final backupHealthProvider = Provider.autoDispose<FeatureHealth>((ref) {
  final settings = ref.watch(backupSettingsProvider);
  // Reading the copy's account probes every account, so only while a copy is
  // missing. Read here, in the foreground: the scheduled backup's isolate
  // has no Google session even on a healthy account.
  final copyMissing =
      settings.cloudBackupEnabled && settings.lastCloudCopyMissing;
  final copyStatus = copyMissing
      ? backupCopyStatusOf(ref.watch(backupCopyTargetProvider).value)
      : null;
  return evaluateBackupHealth(
    BackupHealthInputs(
      autoEnabled: settings.enabled,
      frequency: settings.frequency,
      lastBackupAt: settings.lastBackupTime,
      lastScheduledFailureAt: settings.lastScheduledFailureAt,
      cloudBackupEnabled: settings.cloudBackupEnabled,
      lastCloudCopyMissing: settings.lastCloudCopyMissing,
      lastCloudCopyNeedsSignIn: settings.lastCloudCopyNeedsSignIn,
      copyAccountNeedsSignIn: copyStatus == AccountStatus.needsSignIn,
      lastExtraCopyMissing: settings.lastExtraCopyMissingIds.isNotEmpty,
      extraCopyMissingIds: settings.lastExtraCopyMissingIds,
      hasCustomLocation: settings.backupLocation != null,
      syncConfigured: ref.watch(isSyncEnabledProvider),
    ),
    DateTime.now(),
  );
});

// autoDispose so each visit re-reads the clock (the 7-day offline grace),
// and a select so sync progress ticks do not recompute it.
final syncHealthProvider = Provider.autoDispose<FeatureHealth>((ref) {
  final s = ref.watch(
    syncStateProvider.select(
      (s) => (
        needsPassphrase: s.needsPassphrase,
        awaitingAdoption: s.replaceAwaitingAdoption,
        authenticated: s.isAuthenticated,
        lastSync: s.lastSync,
        conflicts: s.conflicts,
        peersHeld:
            s.newerSchemaPeerLabels.isNotEmpty ||
            s.olderSchemaPeerLabels.isNotEmpty ||
            s.skippedPeerLabels.isNotEmpty ||
            s.readFailedPeerLabels.isNotEmpty,
      ),
    ),
  );
  return evaluateSyncHealth(
    SyncHealthInputs(
      customFolder: ref.watch(isCloudSyncDisabledByCustomFolderProvider),
      providerSelected: ref.watch(selectedCloudProviderTypeProvider) != null,
      providerId: ref.watch(cloudStorageProviderProvider)?.providerId,
      needsPassphrase: s.needsPassphrase,
      awaitingAdoption: s.awaitingAdoption,
      authenticated: s.authenticated,
      lastFailure: ref.watch(syncFailureProvider),
      lastSyncAt: s.lastSync,
      conflicts: s.conflicts,
      peersHeld: s.peersHeld,
      autoSyncEnabled: ref.watch(syncBehaviorProvider).autoSyncEnabled,
    ),
    DateTime.now(),
  );
});

/// Each joined library with this member's listed role resolved.
///
/// Not retried: Riverpod retries a thrown Exception for about 38 seconds,
/// and the Settings > Data libraries row reads "Checking..." until this
/// settles. The next visit reads it again anyway.
final libraryHealthInputsProvider =
    FutureProvider.autoDispose<List<LibraryHealthInput>>((ref) async {
      final libraries = await ref.watch(sharedLibrariesProvider.future);
      return Future.wait([
        for (final l in libraries)
          () async {
            final membership = await ref.watch(
              currentMembershipProvider(l.id).future,
            );
            return LibraryHealthInput(
              id: l.id,
              name: l.name,
              lastError: l.lastError,
              rolesRejected: l.rolesRejected,
              pendingRolesWaiting: l.pendingRoles != null,
              readOnlyDetected: l.readOnlyDetected,
              listedRole: membership == null
                  ? SharedLibraryRole.reader
                  : l.roles.roleOf(membership.memberId),
            );
          }(),
      ]);
    }, retry: (_, _) => null);

final sharedLibrariesHealthProvider = Provider.autoDispose<FeatureHealth>((
  ref,
) {
  final inputs = ref.watch(libraryHealthInputsProvider).value;
  if (inputs == null) return _librariesNotSetUp;
  return evaluateSharedLibraryHealth(inputs);
});

/// Pending setup items that belong to photos and media, split by the row
/// they belong to: attaching or reconnecting the store and sign-ins for an
/// account the store uses (even one that sync uses too: its sign-in routes to
/// the Sync page, yet the uploads stop as well) count as the store; a sign-in
/// for an account only Lightroom uses counts as Lightroom. A dismissed prompt
/// does not count: the diver chose not to be told.
({int store, int lightroom}) countMediaSetupItems(
  List<PendingSetupItem> items,
) {
  var store = 0;
  var lightroom = 0;
  for (final i in items) {
    if (i.dismissed) continue;
    switch (i.kind) {
      case SetupItemKind.mediaStoreAttach || SetupItemKind.mediaStoreReconnect:
        store++;
      case SetupItemKind.accountSignIn
          when i.usages.contains(AccountUsageKind.mediaStorage):
        store++;
      case SetupItemKind.accountSignIn
          when i.usages.contains(AccountUsageKind.lightroom):
        lightroom++;
      case SetupItemKind.accountSignIn:
        break;
    }
  }
  return (store: store, lightroom: lightroom);
}

final mediaHealthInputsProvider = FutureProvider.autoDispose<MediaHealthInputs>(
  (ref) async {
    final items = await ref.watch(pendingSetupItemsProvider.future);
    final lightroom = await ref.watch(lightroomDeviceStatusProvider.future);
    final stores = ref.watch(mediaStoresRepositoryProvider);
    ref.invalidateSelfWhen(stores.watchStoresChanges());
    final store = await stores.getActive();
    // The provider attach and detach flows invalidate, so a fresh attach
    // shows here on return.
    final attached = await ref.watch(mediaStoreAttachedProvider.future);
    // The DB-backed summary only. The suspended flag lives on the media
    // runtime; the marker mismatch behind a suspension already shows as the
    // mediaStoreReconnect setup item.
    final summary = attached
        ? ref.watch(mediaTransferSummaryProvider).value
        : null;
    // Whether the attached store opens with this device's keys (#4561). This
    // resolves the media runtime (keychain read, store build, queue drain)
    // while a store is attached, an accepted cost; still checking (null) is
    // never reported as unreachable.
    final unreachable =
        attached && ref.watch(photosStoreReachableProvider) == false;
    // The account's name probes every account, so only when it is needed.
    String? label;
    if (unreachable) {
      try {
        label = (await ref.watch(photosCopiesProvider.future)).label;
      } on Object {
        label = store?.displayHint;
      }
    }
    final setUp = countMediaSetupItems(items);
    return MediaHealthInputs(
      storeAttachedHere: attached,
      storeAnnounced: store != null,
      lightroomConnected: lightroom == LightroomDeviceStatus.connected,
      storeSetupItems: setUp.store,
      lightroomSetupItems: setUp.lightroom,
      transfersWaitingWithReason:
          summary != null &&
          (summary.waitingReason != null || summary.hold != null),
      storeUnreachable: unreachable,
      storeLabel: label,
    );
  },
);

final mediaHealthProvider = Provider.autoDispose<FeatureHealth>((ref) {
  final inputs = ref.watch(mediaHealthInputsProvider).value;
  if (inputs == null) return _mediaNotSetUp;
  return evaluateMediaHealth(inputs);
});

/// The health provider behind [feature], for a page item that marks itself
/// from its feature's findings (#4561).
ProviderListenable<FeatureHealth> healthProviderOf(DataFeature feature) =>
    switch (feature) {
      DataFeature.backup => backupHealthProvider,
      DataFeature.sync => syncHealthProvider,
      DataFeature.sharedLibraries => sharedLibrariesHealthProvider,
      DataFeature.media => mediaHealthProvider,
    };

/// The four features, one entry each; consumers look a feature up by
/// [FeatureHealth.feature], not by position.
final dataHealthProvider = Provider.autoDispose<List<FeatureHealth>>((ref) {
  return [
    ref.watch(backupHealthProvider),
    ref.watch(syncHealthProvider),
    ref.watch(sharedLibrariesHealthProvider),
    ref.watch(mediaHealthProvider),
  ];
});

final dataFactsProvider = FutureProvider.autoDispose<DataFacts>((ref) async {
  final path = await ref.watch(currentDatabasePathProvider.future);
  return const DataFactsRepository().load(
    DatabaseService.instance.database,
    path,
  );
});
