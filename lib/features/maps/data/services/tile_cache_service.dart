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

  static const String _defaultStoreName = 'submersion_tiles';

  static final LoggerService _log = LoggerService.forClass(TileCacheService);

  bool _initialized = false;
  FMTCStore? _store;
  StreamSubscription<DownloadProgress>? _activeDownloadSubscription;
  Object? _activeDownloadId;

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// The name of the tile store.
  String get storeName => _defaultStoreName;

  /// App Group identifier for macOS sandbox compatibility.
  /// Must match the group in entitlements and be under 20 characters.
  static const String _macosAppGroup = 'group.submersion';

  /// Initialize the tile cache.
  ///
  /// This must be called before using any other methods.
  /// Typically called once at app startup.
  Future<void> initialize() async {
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

    _store = const FMTCStore(_defaultStoreName);
    await _store!.manage.create();
    _initialized = true;
  }

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
    BrowseLoadingStrategy loadingStrategy = BrowseLoadingStrategy.cacheFirst,
  }) {
    _ensureInitialized();
    return FMTCTileProvider(
      stores: {_defaultStoreName: BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: loadingStrategy,
      errorHandler: handleTileError,
    );
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
    _ensureInitialized();
    return FMTCTileProvider(
      stores: {_defaultStoreName: BrowseStoreStrategy.read},
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
    );
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
    _ensureInitialized();

    final stats = await _store!.stats.all;
    return CacheStats(
      tileCount: stats.length,
      sizeKiB: stats.size,
      hits: stats.hits,
      misses: stats.misses,
    );
  }

  /// Clear all cached tiles from the store.
  Future<void> clearCache() async {
    _ensureInitialized();
    await _store!.manage.reset();
  }

  /// Remove tiles older than the specified duration.
  Future<void> removeOldTiles(Duration maxAge) async {
    _ensureInitialized();
    final expiry = DateTime.now().subtract(maxAge);
    await _store!.manage.removeTilesOlderThan(expiry: expiry);
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

    await cancelDownload();
    await FMTCObjectBoxBackend().uninitialise();
    _store = null;
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized || _store == null) {
      throw StateError(
        'TileCacheService not initialized. Call initialize() first.',
      );
    }
  }
}
