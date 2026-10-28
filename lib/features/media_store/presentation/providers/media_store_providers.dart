import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_display_name.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';
import 'package:submersion/core/services/sync/peer_sync_snapshot.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_cache_purge.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_tile_image_memo.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_store_account_attach.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_delete_processor.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_store_preflight.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/orphan_delete_policy.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/platform_video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

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

Future<Directory>? _mediaCacheRootFuture;

/// The on-disk root of the media cache: originals, thumbs, renditions, plus
/// the staging and transcode scratch directories.
///
/// Memoized for the process. Five call sites resolve this (the runtime, the
/// eviction pass, and the three media cache rows on the storage usage page)
/// and each one costs a platform channel round trip that returns the same
/// immutable path every time. Caching the Directory is safe in a way that
/// caching a MediaCacheStore is not: the store captures the LocalCacheDatabase
/// at construction and would go stale after a database location migration,
/// whereas the support directory does not move while the process lives.
///
/// A failed lookup is deliberately not cached, so the next caller retries
/// rather than inheriting a permanent failure from one bad moment at boot.
Future<Directory> mediaCacheRoot() async {
  final cached = _mediaCacheRootFuture;
  if (cached != null) return cached;

  final pending = _resolveMediaCacheRoot();
  _mediaCacheRootFuture = pending;
  try {
    return await pending;
  } catch (_) {
    _mediaCacheRootFuture = null;
    rethrow;
  }
}

Future<Directory> _resolveMediaCacheRoot() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'Submersion', 'media_cache'));
}

/// Drops the memoized [mediaCacheRoot], so a test that overrides the
/// path_provider platform channel is not served another test's directory.
@visibleForTesting
void resetMediaCacheRootForTesting() => _mediaCacheRootFuture = null;

/// The media cache over the live cache database.
///
/// Built per use rather than shared: it captures the cache database at
/// construction, and one held across a database location change would be
/// holding a stale handle.
///
/// With [prefs] the thumbnail pool's cap is the diver's disk cache size
/// (issue #3337), read each time eviction runs so that a change reaches
/// stores already built. Without, the default size applies.
Future<MediaCacheStore> openMediaCacheStore(SharedPreferences? prefs) async =>
    MediaCacheStore(
      database: LocalCacheDatabaseService.instance.database,
      root: await mediaCacheRoot(),
      thumbsCapSource: prefs == null
          ? null
          : () => MediaCacheSettings.fromPrefs(prefs).diskCacheBytes,
    );

/// Empties the thumbnail disk cache, and the decoded images in memory with
/// it: the "Empty cache" button in Photos & Media settings.
///
/// Memory too because a diver who empties the cache to be rid of a wrong
/// thumbnail would otherwise go on seeing it until it happened to leave
/// memory. Originals and compressed copies fetched from the media store are
/// separate pools and are not touched.
// coverage:ignore-start
// Reaches the process-wide cache database and image cache; each half is
// tested where it lives (MediaCacheStore.clear, the settings notifier).
Future<void> emptyThumbnailCache(SharedPreferences? prefs) async {
  await (await openMediaCacheStore(prefs)).clear(MediaCacheKind.thumb);
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}
// coverage:ignore-end

/// SharedPreferences where the container has them, null where it does not.
///
/// [sharedPreferencesProvider] throws unless the root scope overrode it, and
/// the media cache is reached from grid tiles in containers that did not.
SharedPreferences? mediaCachePrefsOrNull(Ref ref) {
  try {
    return ref.read(sharedPreferencesProvider);
  } on Object {
    return null;
  }
}

/// Brings the media cache back inside its LRU caps once per process.
///
/// [MediaCacheStore.evictIfNeeded] is public but was only ever called from
/// inside `put()`, so eviction needed a write to happen. A store that went
/// over cap and then went idle stayed over cap indefinitely, waiting on a
/// download that might never come. Running the same pass on the way up means
/// a library that has stopped fetching still settles back under budget.
///
/// Cached so a runtime rebuild does not repeat it, and deliberately NOT
/// awaited by the runtime: eviction is housekeeping and must never delay a
/// drain.
// no-tick: recomputing is the bug, not the fix. The cached result is what
// keeps this to one pass per process.
final FutureProvider<void> mediaCacheEvictionProvider = FutureProvider<void>((
  ref,
) async {
  final cache = await openMediaCacheStore(mediaCachePrefsOrNull(ref));
  await cache.evictIfNeeded();
});

/// Deletion entry point for UI flows: enqueue-before-delete per the
/// orphan-prevention spec (5.2). The queue and runtime are read lazily
/// (never watched) so consumer widget tests without a media store runtime
/// are unaffected, and the coordinator itself swallows enqueue failures.
// no-tick: builds a coordinator SERVICE, not a cached query result. Its
// repository read sits inside the purge callback and runs per deletion.
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
    // A row leaving the library takes its cached copies with it: unlinking
    // a photo clears its thumbnail off disk and its decoded images out of
    // memory (issue #3337). Read lazily, like the queue above.
    // A delete the user can still undo keeps the media store copies, which
    // would otherwise have to be downloaded again after the undo.
    onDeleted: (items, {required undoable}) => purgeMediaCaches(
      items,
      thumbnails: ref.read(localThumbnailCacheProvider),
      memo: ref.read(mediaTileImageMemoProvider),
      store: undoable
          ? null
          : () => openMediaCacheStore(mediaCachePrefsOrNull(ref)),
      hashStillReferenced: (hash) async =>
          await ref.read(mediaRepositoryProvider).countRowsWithHash(hash) > 0,
    ),
  );
});

/// Builds the cloud orphan delete policy as of now (storage GC design,
/// safety rules). A factory rather than a value: the snapshot, the restore
/// time and whether sync is set up all change between sweeps, and a sweep
/// must judge by the state at its own start.
// no-tick: the value is a CLOSURE; it reads SharedPreferences and the sync
// backend at call time, so there is no cached row to go stale.
final orphanDeletePolicyFactoryProvider =
    Provider<OrphanDeletePolicy Function()>((ref) {
      return () {
        final syncProvider = ref.read(cloudStorageProviderProvider);
        final prefs = ref.read(sharedPreferencesProvider);
        return OrphanDeletePolicy(
          now: DateTime.now(),
          syncEnabled: syncProvider != null,
          currentProviderId: syncProvider?.providerId,
          snapshot: PeerSyncSnapshotStore(prefs).read(),
          lastRestoreAt: StorageGcStore(prefs).lastRestoreAt,
        );
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
/// [MediaTransferQueueRepository.hasOutstandingWork] is one local read that
/// means "some row still needs a runtime": a due row for the drain, a row
/// stranded in transferring for its reclaim, or a deferred row for the
/// worker's wakeup, which exists only once the runtime does (spec 7.1).
/// Finished and failed rows need nothing.
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
      if (!await queue.hasOutstandingWork()) return;
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
    attachState: ref.watch(mediaStoreAttachStateProvider),
    stores: ref.watch(mediaStoresRepositoryProvider),
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

/// Display labels (file name, else caption) for every media row the transfer
/// queue names, in one lean query.
///
/// Keyed on the SET of media ids, not the rows: progress ticks and state
/// changes re-emit the rows many times per transfer without changing which
/// media the queue names, and none of those should touch the media table.
/// A lookup per visible row was the first shape; it hydrated a full
/// MediaItem (imageData BLOB included) into a non-autoDispose family per
/// row and re-ran for every visible row on every media write.
// no-tick: a file name does not change while its upload sits in the queue,
// and the media table ticks on every stamp the upload pipeline writes - about
// three a second through a drain - each of which would re-run the whole label
// query. autoDispose re-resolves the labels the next time the page is built,
// which is the only moment a stale name could be seen.
final mediaTransferLabelsProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      final queued = ref.watch(
        mediaTransferEntriesProvider.select((entries) {
          final rows = entries.value;
          return rows == null
              ? null
              : _QueuedMediaIds(rows.map((e) => e.mediaId));
        }),
      );
      if (queued == null || queued.ids.isEmpty) return const {};
      return ref.watch(mediaRepositoryProvider).getDisplayLabels(queued.ids);
    });

/// The set of media ids the transfer queue names, as a value: `select`
/// compares successive results with `==`, and a List or Set compares by
/// identity, so a fresh collection per emission would defeat the point.
class _QueuedMediaIds {
  _QueuedMediaIds(Iterable<String> ids)
    : ids = List.unmodifiable(ids.toSet().toList()..sort());

  final List<String> ids;

  @override
  bool operator ==(Object other) {
    if (other is! _QueuedMediaIds || other.ids.length != ids.length) {
      return false;
    }
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != other.ids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ids);
}

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

/// The store this device is attached to, for readers that see stamps
/// through it (issue #3482); null when detached or not yet known.
final FutureProvider<String?> mediaAttachedStoreIdProvider =
    FutureProvider<String?>((ref) async {
      try {
        return await ref.watch(mediaStoreAttachStateProvider).attachedStoreId();
      } on Object {
        return null;
      }
    });

/// Call after any media store attach change (connect or disconnect).
///
/// Four providers cache attachment state:
/// [attachedMediaObjectStoreProvider] holds the store adapter,
/// [mediaStoreRuntimeProvider] holds the runtime built from it, and
/// [mediaStoreAttachedProvider] holds the cheap
/// boolean the tile badge reads, and [mediaAttachedStoreIdProvider] the
/// store id stamps are read through. Refreshing only the runtime leaves the
/// badge answering from a stale cache, so a freshly attached store shows
/// no not-backed-up badges until the app restarts, and a disconnected one
/// keeps showing them. Invalidating both together is the whole point of
/// this helper: keep new call sites from having to remember the second.
void invalidateMediaStoreAttachment(WidgetRef ref) =>
    invalidateMediaStoreAttachmentWith(ref.invalidate);

/// [invalidateMediaStoreAttachment] through any invalidate, such as a
/// container's, for a caller whose widget may be gone by the time an attach
/// finishes.
void invalidateMediaStoreAttachmentWith(
  void Function(ProviderOrFamily provider) invalidate,
) {
  // The adapter first: the runtime is built from it, so invalidating the
  // runtime alone would rebuild it around the old store, and a diagnostics
  // report would keep probing a store this device just disconnected from.
  invalidate(attachedMediaObjectStoreProvider);
  invalidate(mediaStoreRuntimeProvider);
  invalidate(mediaStoreAttachedProvider);
  invalidate(mediaAttachedStoreIdProvider);
}

final mediaStoresRepositoryProvider = Provider<MediaStoresRepository>(
  (ref) => MediaStoresRepository(),
);

/// Attach and detach flows for the Photos & videos page.
final mediaStoreServiceProvider = Provider<MediaStoreService>(
  (ref) => MediaStoreService(
    credentials: ref.watch(mediaStoreCredentialsStoreProvider),
    attachState: ref.watch(mediaStoreAttachStateProvider),
    storesRepository: ref.watch(mediaStoresRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
  ),
);

/// Sets up and moves photo copies through an account (issue #3482).
final mediaStoreAccountAttachProvider = Provider<MediaStoreAccountAttach>(
  (ref) => MediaStoreAccountAttach(
    service: ref.watch(mediaStoreServiceProvider),
    accounts: ref.watch(accountGroupServiceProvider),
    registry: ref.watch(accountProviderRegistryProvider),
  ),
);

/// The attached media store's adapter, or null when nothing is attached or
/// the provider cannot be built right now (missing config, no silent Google
/// session, iCloud unavailable). Side-effect free: no worker, no drain, no
/// sweep, so diagnostics can read the store without changing anything.
/// [mediaStoreRuntimeProvider] builds on top of this.
// no-tick: builds a store ADAPTER from attach state, not a cached query
// result. The one repository read (the connected account behind the
// attachment) changes only on connect or disconnect, and both invalidate
// this provider together with the runtime; a tick would rebuild the adapter
// under a drain in flight.
final FutureProvider<MediaObjectStore?> attachedMediaObjectStoreProvider =
    FutureProvider<MediaObjectStore?>((ref) async {
      // Demo mode (issue #3708): no store, so no drain, verify or sweep ever
      // compares the user's real store with the sample logbook.
      if (DemoModeGate.instance.isActive) return null;
      final attachState = ref.watch(mediaStoreAttachStateProvider);
      final attachedId = await attachState.attachedStoreId();
      if (attachedId == null) return null;
      final providerType = await attachState.attachedProviderType();

      // Account-first: attachments made through the Connected Accounts
      // layer resolve their store via the account's adapter. Legacy
      // attachments (no account id) keep the pre-account path unchanged.
      final accountId = await attachState.attachedAccountId();
      if (accountId != null) {
        final account = await ref
            .watch(connectedAccountsRepositoryProvider)
            .getById(accountId);
        if (account == null) return null;
        return buildMediaObjectStoreForAccount(
          account,
          ref.watch(accountProviderRegistryProvider),
        );
      }
      final legacyType = providerType ?? CloudProviderType.s3;
      final s3Config = legacyType == CloudProviderType.s3
          ? await ref.watch(mediaStoreCredentialsStoreProvider).load()
          : null;
      return buildMediaObjectStore(legacyType, s3Config: s3Config);
    });

/// A store resolver for the store gate probe (media sync program spec
/// 7.2), built on the attached adapter alone: no worker, no drain, no sweep,
/// so a probe a grid render makes writes nothing. The runtime's own
/// resolver is not used for it because building the runtime kicks a queue
/// drain and may run a verify sweep. Null when nothing is attached. Kept for
/// the container's life, so its probe answers last the session.
// no-tick: builds a resolver SERVICE from the store adapter, not a cached
// query result. Attach changes invalidate the adapter, which rebuilds this.
final FutureProvider<MediaStoreResolver?> mediaStoreProbeResolverProvider =
    FutureProvider<MediaStoreResolver?>((ref) async {
      final store = await ref.watch(attachedMediaObjectStoreProvider.future);
      if (store == null) return null;
      final resolver = MediaStoreResolver(
        store: store,
        cache: await openMediaCacheStore(mediaCachePrefsOrNull(ref)),
      );
      ref.onDispose(resolver.dispose);
      return resolver;
    });

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
      final store = await ref.watch(attachedMediaObjectStoreProvider.future);
      if (store == null) return null;
      // Fills in the account a store announced before descriptors recorded
      // it, so other devices join it in its own folder. Best effort.
      try {
        await ref.read(mediaStoreServiceProvider).recordAttachedAccount();
      } on Object catch (e) {
        LoggerService.forClass(
          MediaStoreService,
        ).warning('Could not record the media store account: $e');
      }

      final cache = await openMediaCacheStore(mediaCachePrefsOrNull(ref));
      final resolver = MediaStoreResolver(store: store, cache: cache);
      // Same reason as worker.dispose below: a superseded runtime must not
      // leave its resolver's budget timers armed behind the one that
      // replaced it.
      ref.onDispose(resolver.dispose);

      final mediaRepository = ref.watch(mediaRepositoryProvider);
      final policies = ref.watch(mediaStorePoliciesProvider);
      final network = NetworkStatusService();
      final stores = ref.watch(mediaStoresRepositoryProvider);
      final pipeline = MediaUploadPipeline(
        mediaRepository: mediaRepository,
        queue: MediaTransferQueueRepository(),
        store: store,
        registry: ref.watch(mediaSourceResolverRegistryProvider),
        cache: cache,
        quality: ref.watch(mediaUploadQualityPolicyProvider),
        videoTranscoder: PlatformVideoTranscoder(),
        storeId: attachedId,
        takesOver: () async =>
            takesOverStores(attachedId, (await stores.getActive())?.id),
      );
      final deleteProcessor = MediaDeleteProcessor(
        queue: MediaTransferQueueRepository(),
        store: store,
        mediaRepository: mediaRepository,
      );
      // Suspend all transfers when this device detached or when the store no
      // longer carries the marker this device attached to (wiped or
      // repointed; spec section 13).
      final preflight = MediaStorePreflight(
        attachState: attachState,
        store: store,
        attachedStoreId: attachedId,
      );
      final worker = MediaStoreWorker(
        queue: MediaTransferQueueRepository(),
        pipeline: pipeline,
        deleteProcessor: deleteProcessor,
        preflight: preflight.check,
        // Tells a marker read that failed for want of network (a quiet
        // hold) from a store that could not be checked (a suspension).
        isOffline: () async => await network.current() == NetworkKind.offline,
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
      // Fire-and-forget: housekeeping must not delay the drain below.
      //
      // catchError is load-bearing, not decoration. A FutureProvider records
      // the failure in its own AsyncError state, but the future handed back by
      // .future still completes with that error, so an unawaited one surfaces
      // as an unhandled async exception. Same shape as the tile sweep in
      // startup_page.dart. Nothing surfaces this to the user and the retry is
      // a whole launch away, so the log is the only diagnostic there will be.
      unawaited(
        ref.read(mediaCacheEvictionProvider.future).catchError((Object e) {
          debugPrint('Media cache eviction failed (will retry): $e');
        }),
      );

      final connectivitySub = network.changes.listen((kind) {
        if (kind != NetworkKind.offline) unawaited(worker.drain());
      });
      ref.onDispose(connectivitySub.cancel);
      // Cancels only the retry wakeup, not an in-flight drain: a rebuild
      // has never cancelled one, and a superseded worker's timer must not
      // keep re-draining behind the runtime that replaced it.
      ref.onDispose(worker.dispose);
      unawaited(worker.drain());

      return MediaStoreRuntime(
        storeId: attachedId,
        store: store,
        cache: cache,
        resolver: resolver,
        worker: worker,
      );
    });

/// Whether the worker's last preflight suspended the transfer queue (issue
/// #1356). False without a runtime, and it follows the live worker from then
/// on: the queue rows carry no trace of a suspension, so this is the only
/// way the settings pages can tell "paused" from "queued".
// no-tick: mirrors an in-memory worker flag, not a query result.
final mediaTransfersSuspendedProvider = StreamProvider<bool>((ref) async* {
  final runtime = await ref.watch(mediaStoreRuntimeProvider.future);
  final worker = runtime?.worker;
  if (worker == null) {
    yield false;
    return;
  }
  // suspensionChanges opens with the current value, so there is no window
  // between sampling it and subscribing.
  yield* worker.suspensionChanges;
});

/// The store-fallback resolver for display surfaces, or null when no store
/// runtime exists yet. Synchronous accessor over the async runtime.
final mediaStoreResolverProvider = Provider<MediaStoreResolver?>((ref) {
  return ref.watch(mediaStoreRuntimeProvider).value?.resolver;
});

/// Name of the connected store, or null when this device has no store
/// attached: the nickname of the account it was attached through, else its
/// display hint ("bucket @ host") with a well-known service's host named
/// (issue #3522).
final mediaStoreStatusHintProvider = FutureProvider<String?>((ref) async {
  final runtime = await ref.watch(mediaStoreRuntimeProvider.future);
  if (runtime == null) return null;
  final storesRepository = ref.watch(mediaStoresRepositoryProvider);
  final accounts = ref.watch(connectedAccountsRepositoryProvider);
  ref
    ..invalidateSelfWhen(storesRepository.watchStoresChanges())
    // A rename ticks the roster.
    ..invalidateSelfWhen(accounts.watchAccountsChanges());
  final active = await storesRepository.getActive();
  if (active == null) return runtime.storeId;
  return mediaStoreName(
    active,
    attachState: ref.watch(mediaStoreAttachStateProvider),
    accounts: accounts,
  );
});

/// The name [store] is shown under (issue #3522): the nickname of the
/// account this device attached it through, else its display hint with a
/// well-known service's host named. The nickname applies only while this
/// device is attached to [store] itself: after another device switches
/// stores, the account it attached through points somewhere else.
Future<String> mediaStoreName(
  MediaStoreDescriptor store, {
  required MediaStoreAttachState attachState,
  required ConnectedAccountsRepository accounts,
}) async {
  String? nickname;
  if (await attachState.attachedStoreId() == store.id) {
    final accountId = await attachState.attachedAccountId();
    if (accountId != null) {
      nickname = (await accounts.getById(accountId))?.nickname;
    }
  }
  return accountDisplayName(label: store.displayHint, nickname: nickname);
}

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
