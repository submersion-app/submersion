import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_health_report.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

/// Assembles [MediaHealthReport]s from everything this device knows about a
/// media row: the synced columns, the pending mark, the local asset cache,
/// a fresh resolver verdict, the attached store and the transfer queue.
///
/// Diagnostics must never change what they observe, so the store is reached
/// through a plain adapter lookup, never the media store runtime (building
/// that starts a drain and a verification sweep).
class MediaHealthReporter {
  MediaHealthReporter({
    required MediaRepository mediaRepository,
    required SyncRepository syncRepository,
    required LocalAssetCacheRepository assetCache,
    required MediaTransferQueueRepository queue,
    required MediaSourceResolverRegistry registry,
    required MediaStoreAttachState attachState,
    required Future<MediaObjectStore?> Function() store,
    required Future<String> Function() localDeviceId,
    required Future<String?> Function() localDeviceName,
    required String? Function(String deviceId) deviceName,
    DateTime Function()? now,
  }) : _mediaRepository = mediaRepository,
       _syncRepository = syncRepository,
       _assetCache = assetCache,
       _queue = queue,
       _registry = registry,
       _attachState = attachState,
       _store = store,
       _localDeviceId = localDeviceId,
       _localDeviceName = localDeviceName,
       _deviceName = deviceName,
       _now = now ?? DateTime.now;

  final MediaRepository _mediaRepository;
  final SyncRepository _syncRepository;
  final LocalAssetCacheRepository _assetCache;
  final MediaTransferQueueRepository _queue;
  final MediaSourceResolverRegistry _registry;
  final MediaStoreAttachState _attachState;
  final Future<MediaObjectStore?> Function() _store;
  final Future<String> Function() _localDeviceId;
  final Future<String?> Function() _localDeviceName;
  final String? Function(String deviceId) _deviceName;
  final DateTime Function() _now;

  /// The repository's backoff ladder, indexed by attempt count as it does
  /// (`LocalAssetCacheRepository.isExpired`). Mirrored here so the report
  /// can say when the next gallery search is allowed; the reporter test pins
  /// both ends so a change to one shows up in the other.
  static const _backoffLadder = [
    Duration(hours: 24),
    Duration(days: 3),
    Duration(days: 7),
  ];

  /// A one-row report with the full header, so clipboard diagnostics for
  /// one photo carry the store verdict too.
  Future<MediaHealthReport> forItem(
    MediaItem item, {
    bool probeStore = false,
  }) async {
    final me = await _localDeviceId();
    final pending = await _pendingMediaIds();
    final row = await _row(
      item,
      me: me,
      pending: pending.contains(item.id),
      probeStore: probeStore,
    );
    return _report(me, [row]);
  }

  Future<MediaHealthReport> forLibrary({bool probeStore = false}) async {
    final me = await _localDeviceId();
    final pending = await _pendingMediaIds();
    final items = await _mediaRepository.getAllBySourceTypes(
      MediaSourceType.values.toSet(),
    );
    final rows = <MediaHealthRow>[
      for (final item in items)
        await _row(
          item,
          me: me,
          pending: pending.contains(item.id),
          probeStore: probeStore,
        ),
    ];
    return _report(me, rows);
  }

  Future<Set<String>> _pendingMediaIds() async {
    final records = await _syncRepository.getPendingRecords();
    return {
      for (final r in records)
        if (r.entityType == 'media') r.recordId,
    };
  }

  Future<MediaHealthReport> _report(
    String me,
    List<MediaHealthRow> rows,
  ) async {
    final attached = await _attachState.attachedStoreId();
    String? marker;
    final store = await _store();
    if (store != null) {
      try {
        marker = (await StoreMarkerStore(store: store).read())?.storeId;
      } catch (_) {
        marker = null;
      }
    }
    return MediaHealthReport(
      generatedAt: _now(),
      deviceId: me,
      deviceName: await _localDeviceName(),
      attachedStoreId: attached,
      markerStoreId: marker,
      rows: rows,
    );
  }

  Future<MediaHealthRow> _row(
    MediaItem item, {
    required String me,
    required bool pending,
    required bool probeStore,
  }) async {
    final cache = await _assetCache.getCacheEntry(item.id);
    final cacheExpired = cache == null
        ? null
        : await _assetCache.isExpired(item.id);
    final cacheNextRetryAt =
        (cache == null || cache.resolutionMethod != 'unresolved')
        ? null
        : DateTime.fromMillisecondsSinceEpoch(cache.resolvedAt).add(
            _backoffLadder[cache.attemptCount.clamp(
              0,
              _backoffLadder.length - 1,
            )],
          );
    final hlc = await _mediaRepository.getSyncHlc(item.id);

    // verify(), never resolve(): resolve is the BYTES path, so a library
    // report would read every local file and decode every gallery asset.
    //
    // And only for the source types whose verify() is a local read. The
    // others are reported from stored state, which is not a lesser answer:
    // each has a dedicated service that owns the live check, and the row
    // already carries what that service last wrote.
    final skip = _skipReason(item.sourceType);
    String verdict;
    if (skip != null) {
      verdict = skip;
    } else {
      try {
        verdict =
            (await _registry.resolverFor(item.sourceType).verify(item)).name;
      } catch (e) {
        verdict = 'error: $e';
      }
    }

    final probe = probeStore ? await _probeStore(item) : null;

    final entry = await _queue.watchLatestForMedia(item.id).first;
    final nextAttempt = entry?.nextAttemptAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(entry!.nextAttemptAt!);

    final origin = item.originDeviceId;
    final originName = origin == null
        ? null
        : (origin == me ? await _localDeviceName() : _deviceName(origin));

    return MediaHealthRow(
      mediaId: item.id,
      sourceType: item.sourceType.name,
      originalFilename: item.originalFilename,
      filePath: item.filePath,
      localPath: item.localPath,
      platformAssetId: item.platformAssetId,
      pointer: OriginFacts.from(item).pointer,
      takenAt: item.takenAt,
      diveId: item.diveId,
      siteId: item.siteId,
      originDeviceId: origin,
      originDeviceName: originName,
      linkedHere: origin == null ? null : origin == me,
      contentHash: item.contentHash,
      contentSizeBytes: item.contentSizeBytes,
      remoteUploadedAt: item.remoteUploadedAt,
      remoteThumbUploadedAt: item.remoteThumbUploadedAt,
      remoteCompressedUploadedAt: item.remoteCompressedUploadedAt,
      isOrphaned: item.isOrphaned,
      lastVerifiedAt: item.lastVerifiedAt,
      hlc: hlc,
      pending: pending,
      cachedAssetId: cache?.localAssetId,
      cacheMethod: cache?.resolutionMethod,
      cacheAttempts: cache?.attemptCount,
      cacheExpired: cacheExpired,
      cacheNextRetryAt: cacheNextRetryAt,
      resolverVerdict: verdict,
      storeObjectExists: probe?.exists,
      storeObjectTier: probe?.tier,
      queueState: entry?.state,
      queueAttempts: entry?.attempts,
      queueNextAttemptAt: nextAttempt,
      queueWaiting: entry == null
          ? null
          : nextAttempt != null && nextAttempt.isAfter(_now()),
      queueError: entry?.errorMessage,
    );
  }

  /// Why this source type is reported from stored state instead of a live
  /// verify, or null when its verify() is a local read and runs.
  ///
  /// A report must not change what it observes, and must not phone home.
  static String? _skipReason(MediaSourceType type) => switch (type) {
    // The store resolver reaches mediaStoreResolverProvider, which watches
    // the runtime, and building that starts a transfer drain and a verify
    // sweep. The store probe is this row's verdict instead.
    MediaSourceType.mediaStore => 'mediaStore',

    // A gallery verify runs AssetResolutionService, which on a miss writes
    // the local asset cache: the attempt count goes up and resolvedAt is
    // reset to now, so the next automatic search moves from 24 hours out to
    // 3 days and then a week. Producing a report would delay the recovery
    // of the very photos it is describing. The cache block on this row is
    // that service's state, reported rather than disturbed.
    MediaSourceType.platformGallery => 'notProbed: gallery',

    // These verify by fetching a byte range from the host, so a library
    // report would make one request per row, serially, to third parties.
    // NetworkScanService owns that check, with a per-host rate limiter and
    // stored credentials; is_orphaned and last_verified_at below are its
    // findings.
    MediaSourceType.networkUrl ||
    MediaSourceType.manifestEntry => 'notProbed: network',

    // Local reads: a file stat, an account flag, the row's own bytes.
    MediaSourceType.localFile ||
    MediaSourceType.serviceConnector ||
    MediaSourceType.signature => null,
  };

  /// The pipeline stores an original under the object key, a compressed-only
  /// upload under the rendition key and a thumb under the thumb key, so the
  /// namespace follows the stamps. With no stamps at all (the lost-stamp
  /// case) every namespace is tried, in that order, so the row stays
  /// diagnosable. A throw reads as "not probed" rather than "missing".
  Future<({bool? exists, String? tier})> _probeStore(MediaItem item) async {
    final hash = item.contentHash;
    if (hash == null) return (exists: null, tier: null);
    final store = await _store();
    if (store == null) return (exists: null, tier: null);
    final ext = StoreKeys.extensionFor(item.originalFilename);
    // A rendition is written under the COMPRESSED extension the pipeline
    // produces (jpg for an image, mp4 for a video), not the original's, so
    // probing with the original's would report a .heic or .mov rendition
    // missing (media_upload_pipeline.dart).
    final renditionExt = item.mediaType == MediaType.video ? 'mp4' : 'jpg';
    final stamped = <(String, String)>[
      if (item.remoteUploadedAt != null)
        ('original', StoreKeys.objectKey(hash, extension: ext)),
      if (item.remoteCompressedUploadedAt != null)
        ('rendition', StoreKeys.renditionKey(hash, ext: renditionExt)),
      if (item.remoteThumbUploadedAt != null)
        ('thumbnail', StoreKeys.thumbKey(hash)),
    ];
    final probes = stamped.isNotEmpty
        ? stamped
        : <(String, String)>[
            ('original', StoreKeys.objectKey(hash, extension: ext)),
            ('rendition', StoreKeys.renditionKey(hash, ext: renditionExt)),
            ('thumbnail', StoreKeys.thumbKey(hash)),
          ];
    try {
      for (final (tier, key) in probes) {
        if (await store.head(key) != null) return (exists: true, tier: tier);
      }
      return (exists: false, tier: null);
    } catch (_) {
      return (exists: null, tier: null);
    }
  }
}
