import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
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

FeatureHealth _healthOf(Ref ref, DataFeature feature) =>
    ref.watch(dataHealthProvider).firstWhere((h) => h.feature == feature);

/// Label of the roster row that drives sync, or null when sync has no
/// account. A pure read: nothing here creates or re-stamps the row.
final syncAccountLabelProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final accounts = ref.watch(connectedAccountsRepositoryProvider);
  // setSyncAccount notifies the sync event bus; a relabel or removal of the
  // row ticks the roster.
  ref
    ..invalidateSelfWhen(SyncEventBus.changes)
    ..invalidateSelfWhen(accounts.watchAccountsChanges());
  final id = await ref.watch(syncRepositoryProvider).getSyncAccountId();
  if (id == null) return null;
  final account = await accounts.getById(id);
  return account?.label;
});

/// Display hint of the store this device is attached to ("bucket @ host"),
/// or null when none is attached.
final attachedStoreHintProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final stores = ref.watch(mediaStoresRepositoryProvider);
  ref.invalidateSelfWhen(stores.watchStoresChanges());
  final inputs = ref.watch(mediaHealthInputsProvider).value;
  if (inputs == null || !inputs.storeAttachedHere) return null;
  final store = await stores.getActive();
  return store?.displayHint;
});

/// Whether backups also go to the cloud and whether a custom folder is set.
final backupCopyInputsProvider =
    Provider.autoDispose<
      ({bool cloudCopyOn, bool customFolder, bool cloudCopyMissing})
    >((ref) {
      final settings = ref.watch(backupSettingsProvider);
      return (
        cloudCopyOn: settings.cloudBackupEnabled,
        customFolder: settings.backupLocation != null,
        cloudCopyMissing: settings.lastCloudCopyMissing,
      );
    });

/// Whether this device is attached to a media store, or null while that is
/// still loading. Lightroom alone does not count: it keeps no copies. A
/// failed read counts as not attached, so the row never waits forever.
final mediaStoreAttachedHereProvider = Provider.autoDispose<bool?>((ref) {
  final inputs = ref.watch(mediaHealthInputsProvider);
  if (inputs.hasError) return false;
  return inputs.value?.storeAttachedHere;
});

/// How many libraries this device has joined and the latest sync among them,
/// or null while the library list is still loading.
final sharedLibrarySummaryProvider =
    Provider.autoDispose<({int count, DateTime? lastSync})?>((ref) {
      final async = ref.watch(sharedLibrariesProvider);
      // A failed read matches the strip, which reads it as none joined.
      final libraries = async.hasError ? const <SharedLibrary>[] : async.value;
      if (libraries == null) return null;
      DateTime? latest;
      for (final library in libraries) {
        final at = library.lastSyncAt;
        if (at != null && (latest == null || at.isAfter(latest))) latest = at;
      }
      return (count: libraries.length, lastSync: latest);
    });

/// The roster's account labels and how many accounts need a sign-in here.
///
/// The sign-in count comes from the pending setup items the page already
/// computes for the Photos health, never from a status probe of its own:
/// probes read the keychain and can refresh a Google token over the network.
final accountsSummaryProvider =
    FutureProvider.autoDispose<({List<String> labels, int needSignIn})>((
      ref,
    ) async {
      final repository = ref.watch(connectedAccountsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchAccountsChanges());
      final accounts = await repository.getAll();
      // The roster still lists when the sign-in check fails (a keychain
      // error); the count of sign-ins needed then reads as none.
      final items = await ref
          .watch(pendingSetupItemsProvider.future)
          .catchError((Object _) => const <PendingSetupItem>[]);
      return (
        labels: [for (final account in accounts) account.label],
        needSignIn: items
            .where((i) => i.kind == SetupItemKind.accountSignIn)
            .length,
      );
    });

final backupsRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final copy = ref.watch(backupCopyInputsProvider);
  return backupsRowStatus(
    health: _healthOf(ref, DataFeature.backup),
    lastBackup: ref.watch(lastBackupTimeProvider),
    cloudCopyOn: copy.cloudCopyOn,
    cloudAccountLabel: ref.watch(syncAccountLabelProvider).value,
    customFolder: copy.customFolder,
    cloudCopyMissing: copy.cloudCopyMissing,
  );
});

/// Names the other devices on the library have published.
final syncPeerNamesProvider = Provider.autoDispose<List<String>>((ref) {
  final peers = ref.watch(peerDeviceNamesProvider).value ?? const {};
  return peers.values.toList();
});

final syncRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  return syncRowStatus(
    health: _healthOf(ref, DataFeature.sync),
    lastSync: ref.watch(lastSyncTimeProvider),
    peerNames: ref.watch(syncPeerNamesProvider),
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
  if (summary == null) return const DataRowStatus(DataRowStatusKind.checking);
  return librariesRowStatus(
    health: _healthOf(ref, DataFeature.sharedLibraries),
    count: summary.count,
    lastSync: summary.lastSync,
  );
});

final accountsRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final summary = ref.watch(accountsSummaryProvider).value;
  if (summary == null) return const DataRowStatus(DataRowStatusKind.checking);
  return accountsRowStatus(
    labels: summary.labels,
    needSignIn: summary.needSignIn,
  );
});
