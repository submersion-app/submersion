import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_store_preflight.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_gc_providers.dart';

// The media store sweeps the storage cleanup and Verify Library run, and the
// gates every delete in them passes (issue #3396).

/// How long a cleanup or Transfers action waits for the media store runtime.
/// Riverpod retries a build that throws, and with nothing listening to the
/// provider the future it hands out never completes; unbounded, one failed
/// build would hang the cleanup pass (and every run that joins it).
final mediaStoreRuntimeWaitProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 1),
);

/// The runtime a media store sweep may run against.
///
/// Null when no store is attached. Throws when one is attached but cannot be
/// built right now (a lapsed session, a missing credential), so a caller
/// does not mistake it for "not set up"; and when the store fails the marker
/// check the upload worker runs before every transfer (detached, wiped or
/// repointed), since sweeping it would judge another library's objects, or
/// an empty store, against this library's rows.
Future<MediaStoreRuntime?> sweepableMediaStoreRuntime(Ref ref) async {
  final attachState = ref.read(mediaStoreAttachStateProvider);
  final runtime = await ref
      .read(mediaStoreRuntimeProvider.future)
      .timeout(ref.read(mediaStoreRuntimeWaitProvider));
  if (runtime == null) {
    if (await attachState.attachedStoreId() != null) {
      throw StateError('The attached media store is unavailable');
    }
    return null;
  }
  final refusal = await MediaStorePreflight(
    attachState: attachState,
    store: runtime.store,
    attachedStoreId: runtime.storeId,
  ).check();
  if (refusal != null) {
    throw StateError('The media store failed its marker check ($refusal)');
  }
  return runtime;
}

/// Asked before every cloud media delete, by the scheduled cleanup and by
/// Verify Library alike: false throughout while an upload is transferring,
/// and false once a sync or a restore has started since the sweep began
/// (the sweep judged orphans against the rows it read at its start), or the
/// store was detached or repointed (what is left of the listing is no
/// longer this device's store to judge). The attachment is read the same
/// synchronous way it is written, so a change shows at the next delete.
///
/// Take it before building the runtime: that waits on the keychain and the
/// store marker, and a change during the wait must count against the sweep.
Future<bool Function()> mediaSweepDeleteGuard(Ref ref) async {
  final transferring = await ref
      .read(mediaTransferQueueRepositoryProvider)
      .hasTransferringUploads();
  final prefs = ref.read(sharedPreferencesProvider);
  final quiet = SyncCoordinator.quietGuard();
  final notRestored = StorageGcStore.restoreGuard(prefs);
  int generation() => prefs.getInt(MediaStoreAttachState.generationKey) ?? 0;
  String? storeId() => prefs.getString(MediaStoreAttachState.storeIdKey);
  final attachedGeneration = generation();
  final attachedStoreId = storeId();
  return () =>
      !transferring &&
      quiet() &&
      notRestored() &&
      generation() == attachedGeneration &&
      storeId() == attachedStoreId;
}

/// Runs a Verify Library sweep against the attached store, stamps the
/// fleet-wide timestamp on success, and kicks a drain for any queued
/// repairs (orphan-prevention spec 6.3). Throws StateError when no store
/// is attached; the settings action only renders in the connected state.
// no-tick: the value is a CLOSURE, not a query result. Every repository read
// happens inside it at call time via ref.read, so there is no cached row that
// could go stale.
final mediaVerifyRunnerProvider =
    Provider<Future<VerifyLibraryReport> Function()>((ref) {
      // Never beside a cleanup pass: both sweep the same store.
      return () => ref.read(storageGcCoordinatorProvider).exclusive(() async {
        final guard = await mediaSweepDeleteGuard(ref);
        final runtime = await sweepableMediaStoreRuntime(ref);
        if (runtime == null) {
          throw StateError('no media store attached');
        }
        final service = MediaVerifyService(
          store: runtime.store,
          mediaRepository: ref.read(mediaRepositoryProvider),
          queue: ref.read(mediaTransferQueueRepositoryProvider),
          storeId: runtime.storeId,
        );
        // The same gates as the scheduled cleanup: no delete while an upload is
        // transferring, nor during or after a merge, a restore or an
        // attachment change that started once this run began, and none at
        // all from a database that never registered this store (a restore
        // from before it was attached does not know which objects are its).
        final storesRepository = ref.read(mediaStoresRepositoryProvider);
        final policy = ref.read(orphanDeletePolicyFactoryProvider)();
        // Named in the result, as the cleanup names it: only a hold a sync
        // clears may be reported as waiting on a sync.
        final hold = !policy.deletesAllowed
            ? null
            : await storesRepository.getById(runtime.storeId) == null
            ? CloudDeleteHold.unregistered
            : await ref
                  .read(mediaTransferQueueRepositoryProvider)
                  .hasTransferringUploads()
            ? CloudDeleteHold.uploads
            : null;
        final swept = await service.run(
          policy: policy,
          deleteGuard: hold == null ? guard : () => false,
        );
        final report = hold == null ? swept : swept.heldBy(hold);
        // Drain queued repairs BEFORE anything else that can fail: a stamp
        // or record failure must not strand repairs the sweep just queued.
        unawaited(runtime.worker?.drain());
        // The Storage usage page shows what this run reclaimed and found.
        // Display only, so a failed write costs the figures, not the sweep.
        try {
          await ref
              .read(storageGcCoordinatorProvider)
              .recordMediaSweep(report, storeId: runtime.storeId);
        } catch (e) {
          LoggerService.forClass(
            MediaVerifyService,
          ).warning('Recording the verify result failed', error: e);
        }
        // A deferred run deleted nothing; stamping it would hold every
        // device's cleanup off for the fleet cadence.
        if (report.deferred) return report;
        // The swept store's row, as the scheduled cleanup stamps: the newest
        // row may be another store's. A deferred run returned above, and an
        // unregistered store's run is always deferred.
        await storesRepository.stampLastSweep(runtime.storeId, DateTime.now());
        return report;
      });
    });
