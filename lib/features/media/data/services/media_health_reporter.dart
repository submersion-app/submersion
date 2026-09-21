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
import 'package:submersion/features/media/domain/services/diagnostic_probe.dart';
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
    final myName = await _localDeviceName();
    final pending = await _pendingMediaIds();
    final row = await _row(
      item,
      me: me,
      myName: myName,
      pending: pending.contains(item.id),
      probeStore: probeStore,
    );
    return _report(me, myName, [row]);
  }

  Future<MediaHealthReport> forLibrary({bool probeStore = false}) async {
    final me = await _localDeviceId();
    // Resolved once, then carried: the injected lookup rebuilds the answer
    // from a database read and two uncached platform channels every call,
    // and a library is mostly rows linked here, so asking per row turned
    // one export into thousands of round trips.
    final myName = await _localDeviceName();
    final pending = await _pendingMediaIds();
    final items = await _mediaRepository.getAllBySourceTypes(
      MediaSourceType.values.toSet(),
    );
    final rows = <MediaHealthRow>[
      for (final item in items)
        await _row(
          item,
          me: me,
          myName: myName,
          pending: pending.contains(item.id),
          probeStore: probeStore,
        ),
    ];
    return _report(me, myName, rows);
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
    String? myName,
    List<MediaHealthRow> rows,
  ) async {
    final attached = await _attachState.attachedStoreId();
    String? marker;
    // Inside the try as well: a store whose stored credentials no longer
    // parse throws while being BUILT, and every other field in the report
    // is exactly what such a misconfiguration needs. A store that cannot be
    // reached reads as "not probed", never as no report at all.
    try {
      final store = await _store();
      if (store != null) {
        marker = (await StoreMarkerStore(store: store).read())?.storeId;
      }
    } catch (_) {
      marker = null;
    }
    return MediaHealthReport(
      generatedAt: _now(),
      deviceId: me,
      deviceName: myName,
      attachedStoreId: attached,
      markerStoreId: marker,
      rows: rows,
    );
  }

  Future<MediaHealthRow> _row(
    MediaItem item, {
    required String me,
    required String? myName,
    required bool pending,
    required bool probeStore,
  }) async {
    final cache = await _assetCache.getCacheEntry(item.id);
    // Computed from the entry already in hand, not through isExpired, which
    // would fetch the same row again: a library report pays that twice per
    // photo. Same rule as LocalAssetCacheRepository.isExpired, off the same
    // ladder, which the reporter test pins at both ends.
    final cacheExpired = cache == null
        ? null
        : cache.localAssetId != null
        ? false
        : _now().isAfter(
            DateTime.fromMillisecondsSinceEpoch(cache.resolvedAt).add(
              _backoffLadder[cache.attemptCount.clamp(
                0,
                _backoffLadder.length - 1,
              )],
            ),
          );
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
        final resolver = _registry.resolverFor(item.sourceType);
        // The probe where a resolver offers one: LocalFileResolver's verify
        // answers by resolving, and resolve returns the file's whole
        // contents on the bookmark path, so a library report would read
        // every bookmark-backed photo into memory for a one-word verdict.
        // A probe that cannot answer without reading says so.
        if (resolver is DiagnosticProbe) {
          final probed = await (resolver as DiagnosticProbe).probe(item);
          verdict = probed?.name ?? 'notProbed: needs a read';
        } else {
          verdict = (await resolver.verify(item)).name;
        }
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
        : (origin == me ? myName : _deviceName(origin));

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
  ///
  /// Each namespace is LISTED by its key prefix rather than headed by one
  /// exact key. `StoreKeys.extensionFor` is not injective over content, as
  /// `objectKeyPrefix` says: `photo.JPG` and `photo.jpeg` hash identically
  /// but key differently, and a row with no filename lands on `.bin`. The
  /// device that uploaded first fixed the spelling, and every other device
  /// skips the upload once the stamp syncs, so heading this row's own
  /// spelling reported a stored original missing everywhere else, which
  /// reads as store corruption in a support thread. A list is dearer than a
  /// head, and this runs only for the single-row clipboard report; the
  /// library export does not probe the store at all.
  Future<({bool? exists, String? tier})> _probeStore(MediaItem item) async {
    final hash = item.contentHash;
    if (hash == null) return (exists: null, tier: null);
    final store = await _store();
    if (store == null) return (exists: null, tier: null);
    // The thumb key carries no variants (always .jpg), so it stands as its
    // own prefix. The other two end in the dot that keeps one 64-hex hash
    // from prefix-matching a longer one.
    final stamped = <(String, String)>[
      if (item.remoteUploadedAt != null)
        ('original', StoreKeys.objectKeyPrefix(hash)),
      if (item.remoteCompressedUploadedAt != null)
        ('rendition', StoreKeys.renditionKeyPrefix(hash)),
      if (item.remoteThumbUploadedAt != null)
        ('thumbnail', StoreKeys.thumbKey(hash)),
    ];
    final probes = stamped.isNotEmpty
        ? stamped
        : <(String, String)>[
            ('original', StoreKeys.objectKeyPrefix(hash)),
            ('rendition', StoreKeys.renditionKeyPrefix(hash)),
            ('thumbnail', StoreKeys.thumbKey(hash)),
          ];
    try {
      for (final (tier, prefix) in probes) {
        // isEmpty cancels on the first element, so a paged listing stops
        // after one page rather than enumerating the namespace.
        if (!await store.list(prefix).isEmpty) {
          return (exists: true, tier: tier);
        }
      }
      return (exists: false, tier: null);
    } catch (_) {
      return (exists: null, tier: null);
    }
  }
}
