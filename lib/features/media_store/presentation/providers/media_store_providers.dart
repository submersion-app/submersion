import 'dart:async';
import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_delete_processor.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/platform_video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

/// Everything a configured media store needs at runtime. Built once per
/// attach; disposed and rebuilt on connect/disconnect via provider
/// invalidation.
class MediaStoreRuntime {
  final String storeId;
  final MediaObjectStore store;
  final MediaCacheStore cache;
  final MediaStoreResolver resolver;
  final MediaStoreWorker? worker;

  const MediaStoreRuntime({
    required this.storeId,
    required this.store,
    required this.cache,
    required this.resolver,
    this.worker,
  });
}

final mediaStoreCredentialsStoreProvider = Provider<MediaStoreCredentialsStore>(
  (ref) => MediaStoreCredentialsStore(),
);

final mediaStoreAttachStateProvider = Provider<MediaStoreAttachState>(
  (ref) => MediaStoreAttachState(),
);

final mediaStorePoliciesProvider = Provider<MediaStorePolicies>(
  (ref) => MediaStorePolicies(),
);

final mediaUploadQualityPolicyProvider = Provider<MediaUploadQualityPolicy>(
  (ref) => MediaUploadQualityPolicy(),
);

/// Library-wide photo upload level. Watched by the settings page and
/// invalidated on write, mirroring `shareByDefaultProvider`.
final photoUploadQualityProvider = FutureProvider<MediaUploadQuality>(
  (ref) => ref.watch(mediaUploadQualityPolicyProvider).photoUploadQuality(),
);

final videoUploadQualityProvider = FutureProvider<MediaUploadQuality>(
  (ref) => ref.watch(mediaUploadQualityPolicyProvider).videoUploadQuality(),
);

final mediaTransferQueueRepositoryProvider =
    Provider<MediaTransferQueueRepository>(
      (ref) => MediaTransferQueueRepository(),
    );

/// Recovers media transfer rows stranded in 'transferring' by a previous
/// process (app killed or backgrounded mid-upload) back to 'pending'.
///
/// Deliberately separate from [mediaStoreRuntimeProvider] and run exactly
/// once per process. The runtime is rebuilt on every connect/disconnect,
/// and a rebuild can spawn a fresh worker while a worker from the previous
/// runtime is still mid-upload (nothing cancels its in-flight drain).
/// Reclaiming on each rebuild - or inside drain() - would flip that live
/// transfer's row back to 'pending' and let two workers process it at once.
/// A row is only ever orphaned by process death, which is observable only
/// at process start, so running reclamation once before the first drain
/// recovers every real orphan without ever touching a live worker's row.
/// This provider is never invalidated: its cached result makes the reclaim
/// idempotent for the process lifetime. Uses ref.read, not ref.watch, so an
/// invalidation/override of the repository provider (e.g. in a nested test
/// scope) cannot recompute this future and trigger a second reclaim pass.
// no-tick: recomputing is the bug, not the fix. The cached result is what
// makes the reclaim idempotent for the process lifetime; a tick would run a
// second reclaim pass over the queue on every write. The doc comment above
// spells out why it deliberately uses ref.read rather than ref.watch.
final FutureProvider<void> mediaTransferQueueReclaimProvider =
    FutureProvider<void>((ref) async {
      await ref.read(mediaTransferQueueRepositoryProvider).requeueStale();
    });

/// Deletion entry point for UI flows: enqueue-before-delete per the
/// orphan-prevention spec (5.2). The queue and runtime are read lazily
/// (never watched) so consumer widget tests without a media store runtime
/// are unaffected, and the coordinator itself swallows enqueue failures.
final mediaDeletionCoordinatorProvider = Provider<MediaDeletionCoordinator>((
  ref,
) {
  return MediaDeletionCoordinator(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    queue: () => ref.read(mediaTransferQueueRepositoryProvider),
    kickWorker: () async {
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      await runtime?.worker?.drain();
    },
  );
});

/// Runs a Verify Library sweep against the attached store, stamps the
/// fleet-wide timestamp on success, and kicks a drain for any queued
/// repairs (orphan-prevention spec 6.3). Throws StateError when no store
/// is attached; the settings action only renders in the connected state.
// no-tick: the value is a CLOSURE, not a query result. Every repository read
// happens inside it at call time via ref.read, so there is no cached row that
// could go stale.
final mediaVerifyRunnerProvider =
    Provider<Future<VerifyLibraryReport> Function()>((ref) {
      return () async {
        final runtime = await ref.read(mediaStoreRuntimeProvider.future);
        if (runtime == null) {
          throw StateError('no media store attached');
        }
        final service = MediaVerifyService(
          store: runtime.store,
          mediaRepository: ref.read(mediaRepositoryProvider),
          queue: ref.read(mediaTransferQueueRepositoryProvider),
        );
        final report = await service.run();
        // Drain queued repairs BEFORE stamping: a stamp failure (DB/sync)
        // must not strand repairs the sweep just queued.
        unawaited(runtime.worker?.drain());
        final storesRepository = ref.read(mediaStoresRepositoryProvider);
        final active = await storesRepository.getActive();
        if (active != null) {
          await storesRepository.stampLastSweep(active.id, DateTime.now());
        }
        return report;
      };
    });

/// Resumes an outstanding transfer queue at app launch and on app resume
/// (issue #1270).
///
/// Every other drain trigger is downstream of [mediaStoreRuntimeProvider]
/// already existing: the runtime is what kicks the first drain, subscribes to
/// connectivity changes, and lets the worker arm its retry wakeup. Nothing in
/// the launch path ever built it, and the display surfaces cannot stand in for
/// one - the media grid only reaches the store for a row that is already
/// backed up (`MediaItemView`'s storeConfirmed gate), which on a device that
/// has never finished an upload is never true. So a queue that stopped for any
/// reason - the app quit mid-import, a moment offline, a policy hold - had no
/// way back, and the reporter's 196 rows survived every restart untouched.
///
/// Two cheap guards run before anything expensive, because building the
/// runtime opens the keychain and reads the store marker out of the bucket:
/// [mediaStoreAttachedProvider] is one SharedPreferences read (and is
/// documented never to error, which is exactly why it exists), and
/// [MediaTransferQueueRepository.nextPending] is one indexed local read that
/// means precisely "there is work a drain could take right now". A queue
/// holding only deferred rows is left to the worker's own wakeup timer.
///
/// Contains its own failures rather than propagating them: both call sites are
/// fire-and-forget, so an escaping throw would land in the zone handler with
/// nothing to catch it - the shape of #942.
// no-tick: the value is a CLOSURE, not a query result. Every read happens
// inside it at call time via ref.read, so there is no cached row to go stale.
final mediaTransferResumeProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      if (!await ref.read(mediaStoreAttachedProvider.future)) return;
      final queue = ref.read(mediaTransferQueueRepositoryProvider);
      if (await queue.nextPending(DateTime.now()) == null) return;
      // Building the runtime is the kick: see the unawaited drain at the end
      // of mediaStoreRuntimeProvider.
      await ref.read(mediaStoreRuntimeProvider.future);
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(MediaStoreWorker).warning(
        'Could not resume media transfers',
        error: e,
        stackTrace: stackTrace,
      );
    }
  };
});

final mediaBackfillServiceProvider = Provider<MediaBackfillService>(
  (ref) => MediaBackfillService(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    queue: ref.watch(mediaTransferQueueRepositoryProvider),
  ),
);

/// Outstanding transfer work, split into moving / due / parked so the
/// settings page can tell progress from a retry backoff.
final mediaTransferSummaryProvider = StreamProvider<MediaTransferSummary>(
  (ref) => ref.watch(mediaTransferQueueRepositoryProvider).watchSummary(),
);

/// Transfers view feed.
final mediaTransferEntriesProvider =
    StreamProvider<List<MediaTransferQueueEntry>>(
      (ref) => ref.watch(mediaTransferQueueRepositoryProvider).watchEntries(),
    );

/// Whether this device has any media store attached. Deliberately not
/// mediaStoreRuntimeProvider: that constructs the full runtime and kicks a
/// queue drain, which must not happen merely because a media grid scrolled
/// a thumbnail into view. One SharedPreferences read is all the badge needs.
///
/// Never completes with an error. An unreadable attach state (no Flutter
/// binding, unavailable preferences) reads as "not attached", which keeps
/// the tile badge quiet. Watchers must not have to defend against this
/// provider erroring: a watched provider's error becomes the watcher's own
/// error state, which no try/catch in the watcher can intercept.
///
/// Caches for the container's lifetime, so it must be invalidated whenever
/// the attachment changes. Use [invalidateMediaStoreAttachment] rather than
/// invalidating it directly.
final FutureProvider<bool> mediaStoreAttachedProvider = FutureProvider<bool>((
  ref,
) async {
  try {
    final attachState = ref.watch(mediaStoreAttachStateProvider);
    return await attachState.attachedStoreId() != null;
  } on Object {
    return false;
  }
});

/// Call after any media store attach change (connect or disconnect).
///
/// Two providers cache attachment state: [mediaStoreRuntimeProvider] holds
/// the store itself, and [mediaStoreAttachedProvider] holds the cheap
/// boolean the tile badge reads. Refreshing only the runtime leaves the
/// badge answering from a stale cache, so a freshly attached store shows
/// no not-backed-up badges until the app restarts, and a disconnected one
/// keeps showing them. Invalidating both together is the whole point of
/// this helper: keep new call sites from having to remember the second.
void invalidateMediaStoreAttachment(WidgetRef ref) {
  ref.invalidate(mediaStoreRuntimeProvider);
  ref.invalidate(mediaStoreAttachedProvider);
}

final mediaStoresRepositoryProvider = Provider<MediaStoresRepository>(
  (ref) => MediaStoresRepository(),
);

/// Connect/test/disconnect flows for the Media Storage settings page.
final mediaStoreServiceProvider = Provider<MediaStoreService>(
  (ref) => MediaStoreService(
    credentials: ref.watch(mediaStoreCredentialsStoreProvider),
    attachState: ref.watch(mediaStoreAttachStateProvider),
    storesRepository: ref.watch(mediaStoresRepositoryProvider),
  ),
);

/// The configured media store runtime, or null when this device has no
/// store attached. Lazy: the first watcher (a media view or the settings
/// page) triggers construction and a queue drain. Invalidate after connect
/// or disconnect.
// Explicit LHS type: this provider sits on an import cycle (resolver
// registry -> lightroom providers -> this file -> registry), and Dart's
// top-level inference cannot resolve initializer-inferred declarations
// that participate in a cycle.
// no-tick: builds a runtime SERVICE, not a cached query result. Its
// getMediaById call sits inside the queue-drain callback and runs per entry at
// drain time. Lifecycle is imperative by design -- invalidated on store connect
// and disconnect -- and a tick would rebuild the store mid-drain.
final FutureProvider<MediaStoreRuntime?> mediaStoreRuntimeProvider =
    FutureProvider<MediaStoreRuntime?>((ref) async {
      final attachState = ref.watch(mediaStoreAttachStateProvider);
      final attachedId = await attachState.attachedStoreId();
      if (attachedId == null) return null;

      // Account-first: attachments made through the Connected Accounts
      // layer resolve their store via the account's adapter. Legacy
      // attachments (no account id) keep the pre-account path unchanged.
      MediaObjectStore? builtStore;
      final accountId = await attachState.attachedAccountId();
      if (accountId != null) {
        final account = await ref
            .watch(connectedAccountsRepositoryProvider)
            .getById(accountId);
        if (account == null) return null;
        builtStore = await buildMediaObjectStoreForAccount(
          account,
          ref.watch(accountProviderRegistryProvider),
        );
      } else {
        final providerType =
            await attachState.attachedProviderType() ?? CloudProviderType.s3;
        final s3Config = providerType == CloudProviderType.s3
            ? await ref.watch(mediaStoreCredentialsStoreProvider).load()
            : null;
        builtStore = await buildMediaObjectStore(
          providerType,
          s3Config: s3Config,
        );
      }
      final store = builtStore;
      if (store == null) return null;

      final supportDir = await getApplicationSupportDirectory();
      final cache = MediaCacheStore(
        database: LocalCacheDatabaseService.instance.database,
        root: Directory(p.join(supportDir.path, 'Submersion', 'media_cache')),
      );
      final resolver = MediaStoreResolver(store: store, cache: cache);

      final mediaRepository = ref.watch(mediaRepositoryProvider);
      final policies = ref.watch(mediaStorePoliciesProvider);
      final network = NetworkStatusService();
      final pipeline = MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: MediaTransferQueueRepository(),
        store: store,
        registry: ref.watch(mediaSourceResolverRegistryProvider),
        cache: cache,
        quality: ref.watch(mediaUploadQualityPolicyProvider),
        videoTranscoder: PlatformVideoTranscoder(),
      );
      final deleteProcessor = MediaDeleteProcessor(
        queue: MediaTransferQueueRepository(),
        store: store,
        mediaRepository: mediaRepository,
      );
      final worker = MediaStoreWorker(
        queue: MediaTransferQueueRepository(),
        pipeline: pipeline,
        deleteProcessor: deleteProcessor,
        preflight: () async {
          // Suspend all transfers when this device detached (attach state
          // re-read, not captured: disconnect can land while a drain is
          // running) or when the bucket no longer carries the store this
          // device attached to (wiped or repointed; spec section 13).
          final currentId = await attachState.attachedStoreId();
          if (currentId == null || currentId != attachedId) return false;
          final marker = await StoreMarkerStore(store: store).read();
          return marker != null && marker.storeId == currentId;
        },
        gate: (entry) async {
          // Network policies (design spec section 9): offline halts the
          // drain; cellular defers anything the policy disallows.
          final kind = await network.current();
          if (kind == NetworkKind.offline) return WorkerGate.stopDraining;
          // Deletes are tiny API calls with no payload: exempt from the
          // cellular media policies, gated only by being online
          // (orphan-prevention spec 5.6).
          if (entry.direction == 'delete') return WorkerGate.proceed;
          if (kind == NetworkKind.cellular) {
            final item = await mediaRepository.getMediaById(entry.mediaId);
            final isVideo = item?.mediaType == MediaType.video;
            final allowed = isVideo
                ? await policies.videosOnCellular()
                : await policies.photosOnCellular();
            if (!allowed) return WorkerGate.deferEntry;
          }
          return WorkerGate.proceed;
        },
      );
      // Recover orphaned 'transferring' rows once per process, and do it
      // BEFORE any drain can start - including a connectivity-triggered one.
      // Awaited before the network subscription is attached so a network
      // event during the await cannot kick a drain that marks a row
      // 'transferring' while requeueStale is still running. Driven via the
      // cached provider (not inside drain()) so a connect/disconnect rebuild
      // cannot reclaim a row a still-running worker from the previous runtime
      // owns; the cache makes it run only once.
      await ref.read(mediaTransferQueueReclaimProvider.future);

      final connectivitySub = network.changes.listen((kind) {
        if (kind != NetworkKind.offline) unawaited(worker.drain());
      });
      ref.onDispose(connectivitySub.cancel);
      // Cancels only the retry wakeup, not an in-flight drain: a rebuild
      // has never cancelled one, and a superseded worker's timer must not
      // keep re-draining behind the runtime that replaced it.
      ref.onDispose(worker.dispose);
      unawaited(worker.drain());

      // Opportunistic Verify Library sweep (orphan-prevention spec 6.4):
      // fleet-wide 30-day cadence on unmetered network only, fire-and-forget
      // so a sweep problem can never break the runtime. The timestamp is
      // synced, so one device's sweep satisfies every device's cadence.
      unawaited(() async {
        try {
          final storesRepository = ref.read(mediaStoresRepositoryProvider);
          final active = await storesRepository.getActive();
          // No descriptor means nowhere to stamp last_sweep_at: without a
          // bail-out the sweep would repeat on EVERY runtime construction
          // with no fleet cadence guard. Leave the degraded state to the
          // manual action (user-initiated, so unguarded repetition is fine).
          if (active == null) return;
          final kind = await network.current();
          if (!shouldAutoVerify(
            lastSweepAt: active.lastSweepAt,
            network: kind,
            now: DateTime.now(),
          )) {
            return;
          }
          final service = MediaVerifyService(
            store: store,
            mediaRepository: mediaRepository,
            queue: ref.read(mediaTransferQueueRepositoryProvider),
          );
          final report = await service.run();
          // Same ordering as the manual runner: repairs drain even when
          // the fleet stamp fails.
          unawaited(worker.drain());
          await storesRepository.stampLastSweep(active.id, DateTime.now());
          LoggerService.forClass(MediaVerifyService).info(
            'Auto verify sweep: ${report.objectsChecked} checked, '
            '${report.orphansRemoved} orphans removed, '
            '${report.repairsQueued} repairs queued, '
            '${report.sessionsAborted} sessions aborted',
          );
        } catch (e) {
          LoggerService.forClass(
            MediaVerifyService,
          ).warning('Auto verify sweep failed', error: e);
        }
      }());

      return MediaStoreRuntime(
        storeId: attachedId,
        store: store,
        cache: cache,
        resolver: resolver,
        worker: worker,
      );
    });

/// The store-fallback resolver for display surfaces, or null when no store
/// runtime exists yet. Synchronous accessor over the async runtime.
final mediaStoreResolverProvider = Provider<MediaStoreResolver?>((ref) {
  return ref.watch(mediaStoreRuntimeProvider).value?.resolver;
});

/// Display hint for the connected store ("bucket @ host"), or null when
/// this device has no store attached.
final mediaStoreStatusHintProvider = FutureProvider<String?>((ref) async {
  final runtime = await ref.watch(mediaStoreRuntimeProvider.future);
  if (runtime == null) return null;
  final storesRepository = ref.watch(mediaStoresRepositoryProvider);
  ref.invalidateSelfWhen(storesRepository.watchStoresChanges());
  final active = await storesRepository.getActive();
  return active?.displayHint ?? runtime.storeId;
});

/// Implementation behind mediaStoreEnqueueProvider: with a runtime
/// attached, imports feed the queue and kick the worker; without one this
/// is a no-op.
final mediaStoreEnqueueImplProvider = Provider<void Function(String)>((ref) {
  return (mediaId) {
    unawaited(() async {
      if (!await ref.read(mediaStorePoliciesProvider).autoUpload()) return;
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      await runtime?.worker?.enqueueAndKick(mediaId);
    }());
  };
});

/// Per-item re-upload at a chosen quality (settings override action).
final mediaStoreReuploadProvider =
    Provider<Future<void> Function(String, MediaUploadQuality)>((ref) {
      return (mediaId, level) async {
        final runtime = await ref.read(mediaStoreRuntimeProvider.future);
        await runtime?.worker?.reuploadAndKick(mediaId, level);
      };
    });

/// Whether this device can transcode video right now (spec section 12).
/// Drives the Linux settings hint; false on platforms without an engine.
///
/// autoDispose so it re-checks each time Settings is re-entered: a plain
/// FutureProvider would cache a `false` (ffmpeg not yet installed) for the
/// container's lifetime, leaving the "install ffmpeg" hint stale after the
/// user installs ffmpeg and comes back.
final videoTranscodeAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => PlatformVideoTranscoder().isAvailable(),
);
