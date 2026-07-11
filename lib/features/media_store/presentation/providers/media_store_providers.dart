import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
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
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
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

/// Per-tile transfer status, mapped purely from the newest queue row for
/// the item: failed/transferring/pending rows badge, done or absent rows
/// read as none. Already-uploaded media never badges because its queue row
/// is marked done on completion (and later purged by deleteDone) - the
/// item's own upload stamps are never consulted. Defensive against an
/// uninitialized local cache database (widget tests): any construction
/// error reads as none.
final mediaBadgeStateProvider =
    StreamProvider.family<MediaBadgeState, MediaItem>((ref, item) {
      try {
        return ref
            .watch(mediaTransferQueueRepositoryProvider)
            .watchLatestForMedia(item.id)
            .map((row) {
              switch (row?.state) {
                case 'failed':
                  return MediaBadgeState.failed;
                case 'transferring':
                  return MediaBadgeState.transferring;
                case 'pending':
                  return MediaBadgeState.queued;
                default:
                  return MediaBadgeState.none;
              }
            });
      } on StateError {
        return Stream.value(MediaBadgeState.none);
      }
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
final mediaStoreRuntimeProvider = FutureProvider<MediaStoreRuntime?>((
  ref,
) async {
  final attachState = ref.watch(mediaStoreAttachStateProvider);
  final attachedId = await attachState.attachedStoreId();
  if (attachedId == null) return null;
  final providerType =
      await attachState.attachedProviderType() ?? CloudProviderType.s3;
  final s3Config = providerType == CloudProviderType.s3
      ? await ref.watch(mediaStoreCredentialsStoreProvider).load()
      : null;
  final store = await buildMediaObjectStore(providerType, s3Config: s3Config);
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
  );
  final worker = MediaStoreWorker(
    queue: MediaTransferQueueRepository(),
    pipeline: pipeline,
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
  final connectivitySub = network.changes.listen((kind) {
    if (kind != NetworkKind.offline) unawaited(worker.drain());
  });
  ref.onDispose(connectivitySub.cancel);
  unawaited(worker.drain());

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
