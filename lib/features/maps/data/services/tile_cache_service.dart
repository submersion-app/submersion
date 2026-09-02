import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Statistics about the tile cache.
class CacheStats {
  final int tileCount;
  final double sizeKiB;
  final int hits;
  final int misses;

  const CacheStats({
    required this.tileCount,
    required this.sizeKiB,
    required this.hits,
    required this.misses,
  });

  /// Hit rate as a percentage (0-100).
  double get hitRate {
    final total = hits + misses;
    if (total == 0) return 0;
    return (hits / total) * 100;
  }

  /// Size formatted as a human-readable string.
  String get formattedSize {
    if (sizeKiB < 1024) {
      return '${sizeKiB.toStringAsFixed(1)} KB';
    }
    if (sizeKiB < 1024 * 1024) {
      return '${(sizeKiB / 1024).toStringAsFixed(1)} MB';
    }
    return '${(sizeKiB / (1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Progress information for a tile download operation.
class TileDownloadProgress {
  final int downloadedTiles;
  final int totalTiles;
  final int failedTiles;
  final double tilesPerSecond;
  final bool isComplete;

  const TileDownloadProgress({
    required this.downloadedTiles,
    required this.totalTiles,
    required this.failedTiles,
    required this.tilesPerSecond,
    required this.isComplete,
  });

  /// Progress as a percentage (0-100).
  double get percentComplete {
    if (totalTiles == 0) return 0;
    return (downloadedTiles / totalTiles) * 100;
  }
}

/// Service for managing map tile caching using flutter_map_tile_caching.
///
/// This service wraps the flutter_map_tile_caching package to provide
/// tile caching functionality for offline map usage.
///
/// Usage:
/// ```dart
/// // Initialize once at app startup
/// await TileCacheService.instance.initialize();
///
/// // Get a tile provider for use with FlutterMap
/// final tileProvider = TileCacheService.instance.getTileProvider();
/// ```
class TileCacheService {
  static TileCacheService? _instance;

  /// Singleton instance of the TileCacheService.
  static TileCacheService get instance => _instance ??= TileCacheService._();

  TileCacheService._();

  /// Downloaded offline regions. Never capped and never swept by age.
  ///
  /// Keeps its original name so an existing install's tiles stay exactly where
  /// they are: this is the store every version before the split wrote to, and
  /// designating it the offline store means the upgrade deletes nothing. Its
  /// legacy contents are a mix of downloaded regions and old browse tiles, and
  /// they stay put, because there is no way to tell after the fact which tile
  /// a diver deliberately downloaded for a trip.
  ///
  /// Eviction cannot make that distinction either. FMTC's
  /// removeOldestTilesAboveLimit orders by lastModified across a whole store,
  /// so a cap or an age sweep here would delete a region downloaded weeks
  /// before a trip, in the one situation where it cannot be re-fetched.
  static const String _offlineStoreName = 'submersion_tiles';

  /// Incidental browse caching. Capped and swept.
  static const String _browseStoreName = 'submersion_tiles_browse';

  static final LoggerService _log = LoggerService.forClass(TileCacheService);

  bool _initialized = false;
  FMTCStore? _store;
  FMTCStore? _browseStore;
  StreamSubscription<DownloadProgress>? _activeDownloadSubscription;
  Object? _activeDownloadId;

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// The name of the offline (downloaded region) tile store.
  String get storeName => _offlineStoreName;

  /// The name of the browse cache store.
  String get browseStoreName => _browseStoreName;

  /// Tile-count cap on the browse store.
  ///
  /// FMTC counts tiles, not bytes. At a typical 20 to 50 KB per tile this is
  /// roughly 100 to 250 MB of incidental map browsing, which is generous for
  /// a dive log and still bounded. Applies ONLY to the browse store: see
  /// [_offlineStoreName] for why the downloaded regions must never be capped.
  static const int browseStoreMaxTiles = 5000;

  /// How long an incidentally browsed tile is kept.
  ///
  /// Applies ONLY to the browse store, for the same reason as the cap.
  static const Duration browseTileMaxAge = Duration(days: 30);

  /// App Group identifier for macOS sandbox compatibility.
  /// Must match the group in entitlements and be under 20 characters.
  static const String _macosAppGroup = 'group.submersion';

  /// Initialize the tile cache.
  ///
  /// This must be called before using any other methods.
  /// Typically called once at app startup.
  Future<void> initialize() async {
    // coverage:ignore-start
    //
    // This and the other FMTC-calling methods below need a live
    // ObjectBox backend, which flutter test has no way to stand up.
    // The routing that decides which store is written, which is where
    // the risk of evicting a downloaded region actually lives, was
    // extracted into browseStoreStrategies and offlineStoreStrategies
    // precisely so it is asserted in tests rather than ignored here.
    if (_initialized) return;

    // For macOS: use App Group container for sandbox compatibility.
    // ObjectBox requires special permissions that the App Group provides.
    // On other platforms, use the standard cache directory.
    if (Platform.isMacOS) {
      await FMTCObjectBoxBackend().initialise(
        macosApplicationGroup: _macosAppGroup,
      );
    } else {
      final cacheDir = await getApplicationCacheDirectory();
      final tileCacheDir = Directory('${cacheDir.path}/fmtc_tiles');
      if (!await tileCacheDir.exists()) {
        await tileCacheDir.create(recursive: true);
      }
      await FMTCObjectBoxBackend().initialise(rootDirectory: tileCacheDir.path);
    }

    _store = const FMTCStore(_offlineStoreName);
    await _store!.manage.create();

    _browseStore = const FMTCStore(_browseStoreName);
    await _browseStore!.manage.create(maxLength: browseStoreMaxTiles);
    // create() does nothing when the store already exists (PutMode.insert,
    // swallowing UniqueViolationException), so the maxLength above never
    // reaches a store created by an earlier build. setMaxLength is the call
    // that actually applies, and it is idempotent.
    await _browseStore!.manage.setMaxLength(browseStoreMaxTiles);

    _initialized = true;
    // coverage:ignore-end
  }

  /// Which stores a browsing map reads and writes, and how.
  ///
  /// The load-bearing invariant is that the offline store is `read` and never
  /// `readUpdateCreate`: browsing must never add to the store that holds
  /// downloaded regions, or the cap on the browse store would be meaningless
  /// and the offline regions would grow without bound.
  ///
  /// A tile already present in the offline store is served from there and is
  /// NOT duplicated into the browse store, because FMTC only reaches its
  /// write-selection step after a network fetch and an existing tile returns
  /// before that (see `internal_tile_browser.dart`). Static and
  /// [visibleForTesting] so the routing can be asserted without standing up an
  /// ObjectBox backend.
  @visibleForTesting
  static Map<String, BrowseStoreStrategy> browseStoreStrategies() => {
    _browseStoreName: BrowseStoreStrategy.readUpdateCreate,
    _offlineStoreName: BrowseStoreStrategy.read,
  };

  /// Read-only across both stores, for the offline-only map view.
  @visibleForTesting
  static Map<String, BrowseStoreStrategy> offlineStoreStrategies() => {
    _browseStoreName: BrowseStoreStrategy.read,
    _offlineStoreName: BrowseStoreStrategy.read,
  };

  /// Get the tile store for advanced operations.
  ///
  /// Throws [StateError] if the service has not been initialized.
  FMTCStore get store {
    _ensureInitialized();
    return _store!;
  }

  /// Get a tile provider that caches tiles.
  ///
  /// This provider can be used with FlutterMap's TileLayer. Read
  /// `mapTileUrlProvider` inside a `ConsumerWidget`/`ConsumerState` so the
  /// URL tracks the user's selected map style.
  ///
  /// Example:
  /// ```dart
  /// class MyMap extends ConsumerWidget {
  ///   @override
  ///   Widget build(BuildContext context, WidgetRef ref) {
  ///     return TileLayer(
  ///       urlTemplate: ref.watch(mapTileUrlProvider),
  ///       tileProvider: TileCacheService.instance.getTileProvider(),
  ///     );
  ///   }
  /// }
  /// ```
  FMTCTileProvider getTileProvider({
    // coverage:ignore-start
    BrowseLoadingStrategy loadingStrategy = BrowseLoadingStrategy.cacheFirst,
  }) {
    _ensureInitialized();
    return FMTCTileProvider(
      stores: browseStoreStrategies(),
      loadingStrategy: loadingStrategy,
      errorHandler: handleTileError,
    );
    // coverage:ignore-end
  }

  /// Handles a tile fetch failure: logs it (offline misses at info, real
  /// transport/HTTP errors at warning) and returns null so the map shows a
  /// blank tile rather than throwing.
  ///
  /// Tile failures are non-fatal and most are simply offline cache misses,
  /// but provider- or transport-level errors (TLS, HTTP rejections, DNS) are
  /// otherwise invisible -- so the full error is captured for the in-app
  /// Debug Log Viewer instead of being silently swallowed. Static and
  /// [visibleForTesting] so the formatting and log-level policy can be
  /// exercised directly, without initialising the cache backend; used as the
  /// [FMTCTileProvider.errorHandler] in [getTileProvider].
  @visibleForTesting
  static Uint8List? handleTileError(FMTCBrowsingError error) {
    final response = error.response;
    final original = error.originalError;
    final details = StringBuffer()
      ..write('Tile load failed [${error.type.name}]')
      ..write(' url=${error.networkUrl}');
    if (response != null) {
      details
        ..write(' httpStatus=${response.statusCode}')
        ..write(' reason=${response.reasonPhrase}')
        ..write(' contentType=${response.headers['content-type']}')
        ..write(' bodyBytes=${response.bodyBytes.length}');
    }
    if (original != null) {
      details.write(
        ' cause=${original.runtimeType}: ${_describeError(original)}',
      );
    }
    // An offline miss is expected; anything else is a real problem.
    if (error.type == FMTCBrowsingErrorType.noConnectionDuringFetch) {
      _log.info(details.toString());
    } else {
      _log.warning(details.toString());
    }
    return null;
  }

  /// The error's own `toString` (which carries the actionable detail, e.g.
  /// `CERTIFICATE_VERIFY_FAILED`), falling back to [Error.safeToString] if
  /// that throws. Guards the [handleTileError] log line so a pathological
  /// `toString` can never throw back out of the error handler and surface as
  /// a map-render exception. Mirrors `CloudStorageException`'s cause handling.
  static String _describeError(Object error) {
    try {
      return error.toString();
    } catch (_) {
      return Error.safeToString(error);
    }
  }

  /// Get a tile provider configured for offline-only usage.
  ///
  /// This provider will only use cached tiles and will not make network
  /// requests.
  FMTCTileProvider getOfflineTileProvider() {
    // coverage:ignore-start
    _ensureInitialized();
    return FMTCTileProvider(
      stores: offlineStoreStrategies(),
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
    );
    // coverage:ignore-end
  }

  /// Estimate the number of tiles in a rectangular region.
  ///
  /// This is useful for showing users an estimate before downloading.
  Future<int> estimateTileCount({
    required LatLng southWest,
    required LatLng northEast,
    required int minZoom,
    required int maxZoom,
    required TileLayer options,
  }) async {
    _ensureInitialized();

    final bounds = LatLngBounds(southWest, northEast);
    final region = RectangleRegion(bounds);
    final downloadableRegion = region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: options,
    );

    return await _store!.download.countTiles(downloadableRegion);
  }

  /// Download tiles for a rectangular region.
  ///
  /// Returns a stream of [TileDownloadProgress] updates.
  ///
  /// Use [cancelDownload] to cancel an ongoing download.
  Stream<TileDownloadProgress> downloadRegion({
    required LatLng southWest,
    required LatLng northEast,
    required int minZoom,
    required int maxZoom,
    required TileLayer options,
    int parallelThreads = 5,
    bool skipExistingTiles = true,
  }) {
    _ensureInitialized();

    // Cancel any existing download
    if (_activeDownloadId != null) {
      _store!.download.cancel(instanceId: _activeDownloadId!);
      _activeDownloadSubscription?.cancel();
    }

    final bounds = LatLngBounds(southWest, northEast);
    final region = RectangleRegion(bounds);
    final downloadableRegion = region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: options,
    );

    _activeDownloadId = DateTime.now().millisecondsSinceEpoch;

    final streams = _store!.download.startForeground(
      region: downloadableRegion,
      parallelThreads: parallelThreads,
      skipExistingTiles: skipExistingTiles,
      instanceId: _activeDownloadId!,
    );

    final controller = StreamController<TileDownloadProgress>();

    _activeDownloadSubscription = streams.downloadProgress.listen(
      (progress) {
        controller.add(
          TileDownloadProgress(
            downloadedTiles: progress.attemptedTilesCount,
            totalTiles: progress.maxTilesCount,
            failedTiles: progress.failedTilesCount,
            tilesPerSecond: progress.tilesPerSecond,
            isComplete: progress.percentageProgress >= 100,
          ),
        );
      },
      onError: controller.addError,
      onDone: () {
        _activeDownloadId = null;
        _activeDownloadSubscription = null;
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Cancel an ongoing download.
  Future<void> cancelDownload() async {
    if (_activeDownloadId != null) {
      await _store!.download.cancel(instanceId: _activeDownloadId!);
      await _activeDownloadSubscription?.cancel();
      _activeDownloadId = null;
      _activeDownloadSubscription = null;
    }
  }

  /// Pause an ongoing download.
  Future<void> pauseDownload() async {
    if (_activeDownloadId != null) {
      await _store!.download.pause(instanceId: _activeDownloadId!);
    }
  }

  /// Resume a paused download.
  void resumeDownload() {
    if (_activeDownloadId != null) {
      _store!.download.resume(instanceId: _activeDownloadId!);
    }
  }

  /// Check if a download is currently paused.
  bool get isDownloadPaused {
    if (_activeDownloadId == null) return false;
    return _store!.download.isPaused(instanceId: _activeDownloadId!);
  }

  /// Get statistics about the tile cache.
  Future<CacheStats> getCacheStats() async {
    // coverage:ignore-start
    _ensureInitialized();

    final offline = await _store!.stats.all;
    final browse = await _browseStore!.stats.all;
    return CacheStats(
      tileCount: offline.length + browse.length,
      sizeKiB: offline.size + browse.size,
      hits: offline.hits + browse.hits,
      misses: offline.misses + browse.misses,
    );
    // coverage:ignore-end
  }

  /// Clear all cached tiles from the store.
  Future<void> clearCache() async {
    // coverage:ignore-start
    _ensureInitialized();
    await _store!.manage.reset();
    await _browseStore!.manage.reset();
    // coverage:ignore-end
  }

  /// Remove browse-cached tiles older than [maxAge].
  ///
  /// Deliberately scoped to the browse store. Running this across the offline
  /// store would delete a region a diver downloaded before a trip, which is
  /// exactly the data the offline feature exists to guarantee.
  Future<void> removeOldTiles(Duration maxAge) async {
    // coverage:ignore-start
    _ensureInitialized();
    final expiry = DateTime.now().subtract(maxAge);
    await _browseStore!.manage.removeTilesOlderThan(expiry: expiry);
    // coverage:ignore-end
  }

  /// Get the list of all available stores.
  Future<List<String>> getAvailableStores() async {
    _ensureInitialized();
    final stores = await FMTCRoot.stats.storesAvailable;
    return stores.map((s) => s.storeName).toList();
  }

  /// Get the total size of all stores in KiB.
  Future<double> getTotalCacheSize() async {
    _ensureInitialized();
    return await FMTCRoot.stats.size;
  }

  /// Uninitialize the tile cache service.
  ///
  /// This should be called when the app is closing to properly
  /// clean up resources.
  Future<void> dispose() async {
    if (!_initialized) return;
    // coverage:ignore-start

    await cancelDownload();
    await FMTCObjectBoxBackend().uninitialise();
    _store = null;
    _browseStore = null;
    _initialized = false;
    // coverage:ignore-end
  }

  void _ensureInitialized() {
    if (!_initialized || _store == null || _browseStore == null) {
      throw StateError(
        'TileCacheService not initialized. Call initialize() first.',
      );
    }
  }
}
