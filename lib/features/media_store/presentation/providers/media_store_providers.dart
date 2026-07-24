import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_badge.dart';

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

final mediaBackfillServiceProvider = Provider<MediaBackfillService>(
  (ref) => MediaBackfillService(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    queue: ref.watch(mediaTransferQueueRepositoryProvider),
  ),
);

/// Pending + transferring count, for the backfill progress row.
final mediaTransferActiveCountProvider = StreamProvider<int>(
  (ref) => ref.watch(mediaTransferQueueRepositoryProvider).watchActiveCount(),
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

/// Per-tile badge status. Transient transfer state outranks persistent
/// backup state: failed > transferring > queued > notBackedUp > none.
///
/// A failed, transferring, or pending queue row maps straight through. A
/// done or absent row is a settled item, and settles to notBackedUp only
/// when a store is attached, the source is uploadable, and the item has no
/// upload stamps.
///
/// The settled check re-reads the row rather than trusting [item]: the
/// tile's snapshot comes from mediaForDiveProvider, a FutureProvider that
/// an upload's stamp write does not invalidate, so the snapshot goes stale
/// the moment an upload completes. Re-reading is race-free because the
/// pipeline calls stampRemoteUploaded before markDone, so the emission
/// reporting done always follows the stamp write.
///
/// Defensive against an uninitialized local cache database or an absent
/// media repository (widget tests): any error reads as none.
final mediaBadgeStateProvider =
    StreamProvider.family<MediaBadgeState, MediaItem>((ref, item) {
      // Synchronous build phase. Every ref.watch must happen here, not in
      // the generator below: an async* body does not start running until
      // Riverpod subscribes to the stream it returns, by which point the
      // build phase is over and a watched dependency's failure becomes
      // this provider's error state instead of a catchable exception.
      // That is what makes the StateError guard below work at all.
      // The repository constructor resolves its database lazily, so the
      // StateError surfaces from watchLatestForMedia, not from the watch.
      // Both must sit inside the guard.
      final Stream<MediaTransferQueueEntry?> rows;
      try {
        rows = ref
            .watch(mediaTransferQueueRepositoryProvider)
            .watchLatestForMedia(item.id);
      } on StateError {
        return Stream.value(MediaBadgeState.none);
      }
      final mediaRepository = ref.watch(mediaRepositoryProvider);
      final attachedFuture = ref.watch(mediaStoreAttachedProvider.future);
      final eligible = kUploadableSources.contains(item.sourceType);

      return () async* {
        final attached = await attachedFuture;

        // Re-evaluated per settled emission so a just-completed upload
        // clears the badge without waiting for the tile snapshot to
        // refresh. getMediaById is a plain call, so its failure on an
        // uninitialized database is catchable here.
        Future<MediaBadgeState> settled() async {
          if (!attached || !eligible) return MediaBadgeState.none;
          try {
            final fresh = await mediaRepository.getMediaById(item.id);
            if (fresh == null || isBackedUp(fresh)) return MediaBadgeState.none;
            return MediaBadgeState.notBackedUp;
          } on Object {
            return MediaBadgeState.none;
          }
        }

        await for (final row in rows) {
          switch (row?.state) {
            case 'failed':
              yield MediaBadgeState.failed;
            case 'transferring':
              yield MediaBadgeState.transferring;
            case 'pending':
              yield MediaBadgeState.queued;
            default:
              yield await settled();
          }
        }
      }();
    });

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
  final active = await ref.watch(mediaStoresRepositoryProvider).getActive();
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
