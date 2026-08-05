import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Status of an asset resolution attempt.
enum ResolutionStatus {
  /// Asset ID was resolved successfully (from cache, original ID, or matching).
  resolved,

  /// No matching asset found on this device.
  unavailable,
}

/// Result of resolving a media item's asset ID on the current device.
class ResolutionResult {
  final String? localAssetId;
  final ResolutionStatus status;

  const ResolutionResult({this.localAssetId, required this.status});
}

/// Service for resolving cross-device photo asset IDs.
///
/// When a database is synced from another device, the platformAssetId
/// values won't resolve locally. This service finds the matching local
/// asset by metadata (filename, timestamp, dimensions) and caches the
/// mapping for future lookups.
///
/// Gallery query coalescing: when multiple photos from the same dive
/// trigger resolution concurrently (e.g., opening a dive with 20 photos),
/// the service caches gallery query results by time range so only one
/// actual gallery scan is performed. The cache is short-lived (30 seconds)
/// to cover the burst of concurrent provider evaluations.
class AssetResolutionService {
  final LocalAssetCacheRepository _cacheRepository;
  final PhotoPickerService _photoPickerService;
  final _log = LoggerService.forClass(AssetResolutionService);

  /// In-flight resolution futures keyed by mediaId to prevent duplicate work.
  final Map<String, Future<ResolutionResult>> _pendingResolutions = {};

  /// Short-lived cache of gallery query results to coalesce concurrent queries.
  /// Keyed by a time-range bucket string (start~end in ms epoch).
  final Map<String, _GalleryQueryCacheEntry> _galleryQueryCache = {};

  AssetResolutionService({
    required LocalAssetCacheRepository cacheRepository,
    required PhotoPickerService photoPickerService,
  }) : _cacheRepository = cacheRepository,
       _photoPickerService = photoPickerService;

  /// Resolve the local asset ID for a media item.
  ///
  /// Resolution order:
  /// 1. Check local cache
  /// 2. Try original platformAssetId (works on originating device)
  /// 3. Search gallery by metadata (tiered matching)
  Future<ResolutionResult> resolveAssetId(MediaItem item) async {
    // Desktop platforms don't use gallery asset IDs
    if (!_photoPickerService.supportsGalleryBrowsing) {
      return ResolutionResult(
        localAssetId: item.platformAssetId,
        status: ResolutionStatus.resolved,
      );
    }

    if (item.platformAssetId == null) {
      return const ResolutionResult(status: ResolutionStatus.unavailable);
    }

    // Check cache first
    final cachedId = await _cacheRepository.getCachedAssetId(item.id);
    if (cachedId != null) {
      // Verify the cached asset is still loadable (may have been deleted)
      final stillLoadable = await _verifyAssetLoadable(cachedId);
      if (stillLoadable) {
        return ResolutionResult(
          localAssetId: cachedId,
          status: ResolutionStatus.resolved,
        );
      }
      // Cached ID is stale -- clear it and fall through to re-resolution
      _log.info('Cached asset $cachedId no longer loadable, clearing cache');
      await _cacheRepository.clearEntry(item.id);
    }

    // Check if we have an unexpired unresolved entry
    final cacheEntry = await _cacheRepository.getCacheEntry(item.id);
    if (cacheEntry != null && cacheEntry.localAssetId == null) {
      final expired = await _cacheRepository.isExpired(item.id);
      if (!expired) {
        return const ResolutionResult(status: ResolutionStatus.unavailable);
      }
    }

    // Deduplicate concurrent resolution requests for the same media
    if (_pendingResolutions.containsKey(item.id)) {
      return _pendingResolutions[item.id]!;
    }

    final future = _resolveFromGallery(item);
    _pendingResolutions[item.id] = future;

    try {
      return await future;
    } finally {
      _pendingResolutions.remove(item.id);
    }
  }

  /// Attempt to resolve by trying the original ID, then metadata matching.
  Future<ResolutionResult> _resolveFromGallery(MediaItem item) async {
    _log.info('Resolving asset for media ${item.id}');

    // Step 2: Try original platformAssetId
    final originalWorks = await _verifyAssetLoadable(item.platformAssetId!);
    if (originalWorks) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: item.platformAssetId!,
        method: 'original_id',
      );
      _log.info('Resolved via original ID: ${item.platformAssetId}');
      return ResolutionResult(
        localAssetId: item.platformAssetId,
        status: ResolutionStatus.resolved,
      );
    }

    // Step 3: Search gallery by metadata (with query coalescing)
    const timeWindow = Duration(seconds: 5);
    final start = item.takenAt.subtract(timeWindow);
    final end = item.takenAt.add(timeWindow);

    List<AssetInfo> candidates;
    try {
      candidates = await _getAssetsCoalesced(start, end);
    } catch (e) {
      _log.error('Gallery query failed for media ${item.id}', error: e);
      return const ResolutionResult(status: ResolutionStatus.unavailable);
    }

    if (candidates.isEmpty) {
      await _cacheUnresolved(item.id);
      return const ResolutionResult(status: ResolutionStatus.unavailable);
    }

    // Tier 1: filename + timestamp
    final tier1Match = matchByFilenameAndTimestamp(item, candidates);
    if (tier1Match != null) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: tier1Match,
        method: 'filename_timestamp',
      );
      _log.info('Resolved via filename+timestamp: $tier1Match');
      return ResolutionResult(
        localAssetId: tier1Match,
        status: ResolutionStatus.resolved,
      );
    }

    // Tier 2: exact capture second + dimensions. This runs BEFORE the fuzzy
    // window below because widening the window destroys the signal for an
    // interval/burst sequence: frames shot every two seconds share their
    // dimensions and carry no usable filename, so +-2s sees the neighbours and
    // gives up, while the exact second identifies the frame outright. Capture
    // timestamps survive an iCloud round-trip unchanged, so an exact hit is
    // trustworthy even when the asset ID came from another device.
    final exactMatch = matchByTimestampAndDimensions(
      item,
      candidates,
      tolerance: Duration.zero,
    );
    if (exactMatch != null) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: exactMatch,
        method: 'exact_timestamp_dimensions',
      );
      _log.info('Resolved via exact timestamp+dimensions: $exactMatch');
      return ResolutionResult(
        localAssetId: exactMatch,
        status: ResolutionStatus.resolved,
      );
    }

    // Tier 3: timestamp within +-2s + dimensions, for rows whose stored
    // capture time drifted from the gallery's (re-imports, editors that
    // rewrite EXIF).
    final tier3Match = matchByTimestampAndDimensions(item, candidates);
    if (tier3Match != null) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: tier3Match,
        method: 'timestamp_dimensions',
      );
      _log.info('Resolved via timestamp+dimensions: $tier3Match');
      return ResolutionResult(
        localAssetId: tier3Match,
        status: ResolutionStatus.resolved,
      );
    }

    // Tier 4: unresolved
    await _cacheUnresolved(item.id);
    _log.info('Could not resolve media ${item.id} -- marked unresolved');
    return const ResolutionResult(status: ResolutionStatus.unavailable);
  }

  /// Verify that a platformAssetId actually loads on this device.
  Future<bool> _verifyAssetLoadable(String assetId) async {
    try {
      final thumbnail = await _photoPickerService.getThumbnail(
        assetId,
        size: 50,
      );
      return thumbnail != null && thumbnail.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cacheUnresolved(String mediaId) async {
    final cacheEntry = await _cacheRepository.getCacheEntry(mediaId);
    if (cacheEntry != null && cacheEntry.resolutionMethod == 'unresolved') {
      // Existing unresolved entry -- increment attempt count
      await _cacheRepository.incrementAttempt(mediaId);
    } else {
      // New unresolved entry
      await _cacheRepository.cacheResolution(
        mediaId: mediaId,
        localAssetId: null,
        method: 'unresolved',
      );
    }
  }

  /// Get gallery assets for a time range, coalescing concurrent queries.
  ///
  /// When opening a dive with many photos, all providers fire near-simultaneously
  /// with overlapping time windows. This method caches the gallery query results
  /// for 30 seconds so only one actual gallery scan is performed per time window.
  Future<List<AssetInfo>> _getAssetsCoalesced(
    DateTime start,
    DateTime end,
  ) async {
    // Round to 1-minute buckets to maximize cache hits across photos
    // from the same dive (whose +-5s windows will overlap heavily)
    final bucketStart = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
    final bucketEnd = DateTime(
      end.year,
      end.month,
      end.day,
      end.hour,
      end.minute + 1,
    );
    final cacheKey =
        '${bucketStart.millisecondsSinceEpoch}~${bucketEnd.millisecondsSinceEpoch}';

    // Check for a valid cached result
    final cached = _galleryQueryCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }

    // Query the gallery and cache the result
    final results = await _photoPickerService.getAssetsInDateRange(
      bucketStart,
      bucketEnd,
    );
    _galleryQueryCache[cacheKey] = _GalleryQueryCacheEntry(
      results: results,
      createdAt: DateTime.now(),
    );

    // Prune expired entries to prevent memory leaks
    _galleryQueryCache.removeWhere((_, entry) => entry.isExpired);

    return results;
  }

  /// Tier 1: Match by original filename and timestamp within +/-5 seconds.
  /// Returns the matching asset ID, or null if zero or multiple matches.
  ///
  /// An EMPTY filename counts as absent, on either side. photo_manager's
  /// darwin layer serializes an asset title as "" (not null) unless
  /// FilterOption.needTitle is set, and imports store that "" verbatim, so
  /// without this guard a null-only check lets '' == '' satisfy the filename
  /// test and quietly degrades this tier into a timestamp-only match that can
  /// bind the wrong asset.
  static String? matchByFilenameAndTimestamp(
    MediaItem item,
    List<AssetInfo> candidates,
  ) {
    final filename = item.originalFilename;
    if (filename == null || filename.isEmpty) return null;

    final matches = candidates.where((c) {
      final candidateName = c.filename;
      if (candidateName == null || candidateName.isEmpty) return false;
      if (candidateName != filename) return false;
      final diff = c.createDateTime.difference(item.takenAt).abs();
      return diff <= const Duration(seconds: 5);
    }).toList();

    return matches.length == 1 ? matches.first.id : null;
  }

  /// Tier 2/3: Match by dimensions and timestamp within [tolerance].
  /// Returns the matching asset ID, or null if zero or multiple matches.
  ///
  /// [tolerance] is caller-supplied because the two useful widths trade off
  /// against each other. [Duration.zero] demands the exact capture second,
  /// which is what separates the frames of an interval/burst sequence
  /// (identical dimensions, no usable filename, neighbours a second or two
  /// away); the default +-2s absorbs clock drift between the stored row and
  /// the gallery but sees those neighbours and refuses to guess.
  static String? matchByTimestampAndDimensions(
    MediaItem item,
    List<AssetInfo> candidates, {
    Duration tolerance = const Duration(seconds: 2),
  }) {
    if (item.width == null || item.height == null) return null;

    final itemSecond = _truncateToSecond(item.takenAt);
    final matches = candidates.where((c) {
      if (c.width != item.width || c.height != item.height) return false;
      final diff = _truncateToSecond(
        c.createDateTime,
      ).difference(itemSecond).abs();
      return diff <= tolerance;
    }).toList();

    return matches.length == 1 ? matches.first.id : null;
  }

  /// Both sides are compared at second granularity so [Duration.zero] means
  /// "the same capture second" rather than "the same instant".
  ///
  /// The two sides do not carry the same precision: photo_manager derives
  /// createDateTime from an integer `createDateSecond`, so a gallery candidate
  /// can never have a sub-second component, while a stored takenAt is epoch
  /// MILLISECONDS and could acquire one from a non-gallery import path. Without
  /// this, such a row could never satisfy the exact tier - no candidate would
  /// be reachable - and it would silently fall through to the ambiguous fuzzy
  /// window that this tier exists to bypass.
  static DateTime _truncateToSecond(DateTime t) {
    final micros = t.microsecondsSinceEpoch;
    // Dart's % is non-negative for a positive divisor, so this floors
    // correctly on both sides of the epoch.
    return DateTime.fromMicrosecondsSinceEpoch(
      micros - (micros % Duration.microsecondsPerSecond),
      isUtc: t.isUtc,
    );
  }
}

/// Short-lived cache entry for gallery query results.
/// Expires after 30 seconds -- long enough to cover the burst of
/// concurrent provider evaluations when opening a dive detail page.
class _GalleryQueryCacheEntry {
  final List<AssetInfo> results;
  final DateTime createdAt;

  static const _ttl = Duration(seconds: 30);

  _GalleryQueryCacheEntry({required this.results, required this.createdAt});

  bool get isExpired => DateTime.now().isAfter(createdAt.add(_ttl));
}
