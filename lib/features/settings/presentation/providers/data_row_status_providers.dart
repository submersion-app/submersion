import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/media_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

/// The one-sentence statuses under the Settings > Data rows (issue #3482).
///
/// Every status reads the feature's health from [dataHealthProvider], the
/// list the strip draws, plus a small leaf input of its own. The leaves are
/// providers so a widget test can override them without a database. None
/// builds the media store runtime or probes an account: opening Settings
/// must not drain the upload queue or add keychain and network calls.
///
/// Leaves read an async value the way the strip does: the value first, so a
/// failed refresh keeps the last good answer (Riverpod keeps it on the
/// error), and the error only when there never was a value.

FeatureHealth _healthOf(Ref ref, DataFeature feature) =>
    ref.watch(dataHealthProvider).firstWhere((h) => h.feature == feature);

/// The connected account the last cloud backup went to, as recorded when it
/// ran, or null for any other destination.
final lastBackupCloudAccountIdProvider = Provider.autoDispose<String?>(
  (ref) => ref.watch(
    backupSettingsProvider.select((s) => s.lastBackupCloudAccountId),
  ),
);

/// Label of the account the last cloud backup went to, not of the account
/// that syncs today: after a switch, the older copy is still in the old
/// one. Null when the account has since been removed, which reads as "the
/// cloud". A pure read: nothing here creates or re-stamps the row.
final lastBackupCloudAccountLabelProvider = FutureProvider.autoDispose<String?>(
  (ref) async {
    final accounts = ref.watch(connectedAccountsRepositoryProvider);
    // A relabel or removal of the row ticks the roster.
    ref.invalidateSelfWhen(accounts.watchAccountsChanges());
    final id = ref.watch(lastBackupCloudAccountIdProvider);
    if (id == null) return null;
    return (await accounts.getById(id))?.label;
  },
);

/// Display hint of the store this device is attached to ("bucket @ host"),
/// or null when none is attached. The attached store, not the one the
/// library announces: after another device switches stores, this device
/// still keeps its copies in the old one until it reattaches.
final attachedStoreHintProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final stores = ref.watch(mediaStoresRepositoryProvider);
  ref.invalidateSelfWhen(stores.watchStoresChanges());
  // The attach and detach flows invalidate this, so a change shows here.
  if (!await ref.watch(mediaStoreAttachedProvider.future)) return null;
  final id = await ref.watch(mediaStoreAttachStateProvider).attachedStoreId();
  if (id == null) return null;
  return (await stores.getById(id))?.displayHint;
});

/// Where the most recent backup went.
final lastBackupDestinationProvider =
    Provider.autoDispose<LastBackupDestination?>(
      (ref) => ref.watch(
        backupSettingsProvider.select((s) => s.lastBackupDestination),
      ),
    );

/// Whether this device is attached to a media store, from the media health
/// inputs: null while they first load, the last known answer after a failed
/// refresh, and not attached when they never loaded.
bool? attachedHereOf(MediaHealthInputs? inputs, {required bool hasError}) =>
    inputs?.storeAttachedHere ?? (hasError ? false : null);

/// Whether this device is attached to a media store, or null while that is
/// still loading. Lightroom alone does not count: it keeps no copies.
final mediaStoreAttachedHereProvider = Provider.autoDispose<bool?>((ref) {
  final inputs = ref.watch(mediaHealthInputsProvider);
  return attachedHereOf(inputs.value, hasError: inputs.hasError);
});

/// The joined libraries: null while they first load, the last known list
/// after a failed refresh, and none when they never loaded (the strip reads
/// that as none joined too).
List<T>? librariesOrNull<T>(List<T>? libraries, {required bool hasError}) =>
    libraries ?? (hasError ? <T>[] : null);

/// How many libraries there are and when the stalest one last synced, so a
/// fresh library never hides one that stopped syncing weeks ago. One that
/// has never synced makes the whole set read as not synced yet.
({int count, DateTime? lastSync}) summarizeLibrarySyncs(
  Iterable<DateTime?> syncs,
) {
  var count = 0;
  var anyNever = false;
  DateTime? oldest;
  for (final at in syncs) {
    count++;
    if (at == null) {
      anyNever = true;
    } else if (oldest == null || at.isBefore(oldest)) {
      oldest = at;
    }
  }
  return (count: count, lastSync: anyNever ? null : oldest);
}

/// How many libraries this device has joined and their stalest sync, or null
/// while the library list is still loading.
final sharedLibrarySummaryProvider =
    Provider.autoDispose<({int count, DateTime? lastSync})?>((ref) {
      final async = ref.watch(sharedLibrariesProvider);
      final libraries = librariesOrNull(async.value, hasError: async.hasError);
      if (libraries == null) return null;
      return summarizeLibrarySyncs(libraries.map((l) => l.lastSyncAt));
    });

/// Whether the library health behind the row mark has loaded (or failed).
/// Until it has, the health reads "not set up" and would hide a failing
/// library behind a plain count.
final libraryHealthSettledProvider = Provider.autoDispose<bool>((ref) {
  final inputs = ref.watch(libraryHealthInputsProvider);
  return inputs.hasValue || inputs.hasError;
});

/// The roster's account labels.
final accountLabelsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final repository = ref.watch(connectedAccountsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchAccountsChanges());
  final accounts = await repository.getAll();
  return [for (final account in accounts) account.label];
});

/// How many accounts need a sign-in on this device, from the pending setup
/// items the page already computes for the Photos health, never from a
/// status probe of its own: probes read the keychain and can refresh a
/// Google token over the network. Dismissed prompts count: dismissing hides
/// the card entry, not the need. Reads as none until the items arrive, so
/// the roster never waits on them.
final accountSignInsNeededProvider = Provider.autoDispose<int>((ref) {
  final items =
      ref.watch(pendingSetupItemsProvider).value ?? const <PendingSetupItem>[];
  return items.where((i) => i.kind == SetupItemKind.accountSignIn).length;
});

final backupsRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final destination = ref.watch(lastBackupDestinationProvider);
  return backupsRowStatus(
    health: _healthOf(ref, DataFeature.backup),
    lastBackup: ref.watch(lastBackupTimeProvider),
    destination: destination,
    // Only a cloud copy names the account, so only then build the label.
    cloudAccountLabel: destination == LastBackupDestination.cloud
        ? ref.watch(lastBackupCloudAccountLabelProvider).value
        : null,
  );
});

/// Names the other devices on the library have published. While the live
/// stream starts, the stored names stand in, so the first frame never reads
/// as no peers.
final syncPeerNamesProvider = Provider.autoDispose<List<String>>((ref) {
  final peers =
      ref.watch(peerDeviceNamesProvider).value ??
      ref.watch(peerDeviceNameStoreProvider).all();
  return peers.values.toList();
});

/// Whether a custom database folder can only be a device volume here, so it
/// cannot be a folder another service syncs.
final syncFolderIsDeviceOnlyProvider = Provider.autoDispose<bool>(
  (ref) => ref
      .watch(storagePlatformCapabilitiesProvider)
      .customFolderIsDeviceVolumeOnly,
);

final syncRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  return syncRowStatus(
    health: _healthOf(ref, DataFeature.sync),
    lastSync: ref.watch(lastSyncTimeProvider),
    peerNames: ref.watch(syncPeerNamesProvider),
    customFolderIsDeviceOnly: ref.watch(syncFolderIsDeviceOnlyProvider),
  );
});

final photosRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final attached = ref.watch(mediaStoreAttachedHereProvider);
  // Until the attach state arrives the health reads "not set up", which
  // would offer Set up to a diver who already keeps copies.
  if (attached == null) return const DataRowStatus(DataRowStatusKind.checking);
  return photosRowStatus(
    health: _healthOf(ref, DataFeature.media),
    storeHint: ref.watch(attachedStoreHintProvider).value,
    storeAttachedHere: attached,
  );
});

final librariesRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final summary = ref.watch(sharedLibrarySummaryProvider);
  if (summary == null || !ref.watch(libraryHealthSettledProvider)) {
    return const DataRowStatus(DataRowStatusKind.checking);
  }
  return librariesRowStatus(
    health: _healthOf(ref, DataFeature.sharedLibraries),
    count: summary.count,
    lastSync: summary.lastSync,
  );
});

final accountsRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final labels = ref.watch(accountLabelsProvider);
  final value = labels.value;
  if (value != null) {
    return accountsRowStatus(
      labels: value,
      needSignIn: ref.watch(accountSignInsNeededProvider),
    );
  }
  if (labels.hasError) {
    return const DataRowStatus(DataRowStatusKind.accountsUnavailable);
  }
  return const DataRowStatus(DataRowStatusKind.checking);
});
