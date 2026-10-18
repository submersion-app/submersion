import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

/// The one-sentence statuses under the Settings > Data rows (issue #3482).
///
/// Every status reads the feature's health from [dataHealthProvider], the
/// list the strip draws, plus a small leaf input of its own. The leaves are
/// providers so a widget test can override them without a database, and
/// none of them builds the media store runtime: opening Settings must not
/// read the keychain or drain the upload queue.

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
    Provider.autoDispose<({bool cloudCopyOn, bool customFolder})>((ref) {
      final settings = ref.watch(backupSettingsProvider);
      return (
        cloudCopyOn: settings.cloudBackupEnabled,
        customFolder: settings.backupLocation != null,
      );
    });

/// How many libraries this device has joined and the latest sync among them.
final sharedLibrarySummaryProvider =
    Provider.autoDispose<({int count, DateTime? lastSync})>((ref) {
      final libraries = ref.watch(sharedLibrariesProvider).value ?? const [];
      DateTime? latest;
      for (final library in libraries) {
        final at = library.lastSyncAt;
        if (at != null && (latest == null || at.isAfter(latest))) latest = at;
      }
      return (count: libraries.length, lastSync: latest);
    });

/// Signed-in account labels and how many accounts need a sign-in here.
final accountsSummaryProvider =
    FutureProvider.autoDispose<({List<String> signedInLabels, int needSignIn})>(
      (ref) async {
        final accounts = await ref.watch(
          connectedAccountsWithStatusProvider.future,
        );
        return (
          signedInLabels: [
            for (final (account, status) in accounts)
              if (status == AccountStatus.signedIn) account.label,
          ],
          needSignIn: accounts
              .where((entry) => entry.$2 == AccountStatus.needsSignIn)
              .length,
        );
      },
    );

final backupsRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final copy = ref.watch(backupCopyInputsProvider);
  return backupsRowStatus(
    health: _healthOf(ref, DataFeature.backup),
    lastBackup: ref.watch(lastBackupTimeProvider),
    cloudCopyOn: copy.cloudCopyOn,
    cloudAccountLabel: ref.watch(syncAccountLabelProvider).value,
    customFolder: copy.customFolder,
  );
});

final syncRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final peers = ref.watch(peerDeviceNamesProvider).value ?? const {};
  return syncRowStatus(
    health: _healthOf(ref, DataFeature.sync),
    lastSync: ref.watch(lastSyncTimeProvider),
    peerNames: peers.values.toList(),
  );
});

final photosRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  return photosRowStatus(
    health: _healthOf(ref, DataFeature.media),
    storeHint: ref.watch(attachedStoreHintProvider).value,
  );
});

final librariesRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final summary = ref.watch(sharedLibrarySummaryProvider);
  return librariesRowStatus(
    health: _healthOf(ref, DataFeature.sharedLibraries),
    count: summary.count,
    lastSync: summary.lastSync,
  );
});

final accountsRowStatusProvider = Provider.autoDispose<DataRowStatus>((ref) {
  final summary = ref.watch(accountsSummaryProvider).value;
  return accountsRowStatus(
    signedInLabels: summary?.signedInLabels ?? const [],
    needSignIn: summary?.needSignIn ?? 0,
  );
});
