import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/data/repositories/offline_map_repository.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';

/// Provider for the offline map repository.
final offlineMapRepositoryProvider = Provider<OfflineMapRepository>((ref) {
  return OfflineMapRepository();
});

/// Provider for the tile cache service.
final tileCacheServiceProvider = Provider<TileCacheService>((ref) {
  return TileCacheService.instance;
});

/// Provider for all cached regions.
final cachedRegionsProvider = FutureProvider<List<CachedRegion>>((ref) async {
  final repository = ref.watch(offlineMapRepositoryProvider);
  return repository.getAllRegions();
});

/// Provider for cache statistics.
final cacheStatsProvider = FutureProvider<CacheStats>((ref) async {
  final service = ref.watch(tileCacheServiceProvider);
  return service.getCacheStats();
});

/// State for region download progress.
class DownloadState {
  final bool isDownloading;
  final double progress;
  final int downloadedTiles;
  final int totalTiles;
  final int failedTiles;
  final double tilesPerSecond;
  final String? regionName;
  final String? error;

  const DownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.downloadedTiles = 0,
    this.totalTiles = 0,
    this.failedTiles = 0,
    this.tilesPerSecond = 0.0,
    this.regionName,
    this.error,
  });

  DownloadState copyWith({
    bool? isDownloading,
    double? progress,
    int? downloadedTiles,
    int? totalTiles,
    int? failedTiles,
    double? tilesPerSecond,
    String? regionName,
    String? error,
    bool clearError = false,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      totalTiles: totalTiles ?? this.totalTiles,
      failedTiles: failedTiles ?? this.failedTiles,
      tilesPerSecond: tilesPerSecond ?? this.tilesPerSecond,
      regionName: regionName ?? this.regionName,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Whether the download has completed (with or without errors).
  bool get isComplete => !isDownloading && downloadedTiles > 0;

  /// Whether the download completed with errors.
  bool get hasErrors => error != null || failedTiles > 0;
}

/// Notifier for managing region downloads.
class DownloadProgressNotifier extends StateNotifier<DownloadState> {
  final TileCacheService _cacheService;
  final OfflineMapRepository _repository;
  final Ref _ref;

  DownloadProgressNotifier(this._cacheService, this._repository, this._ref)
    : super(const DownloadState());

  /// Download tiles for a rectangular region.
  ///
  /// The [tileLayerOptions] should be configured with the URL template
  /// for the tile server (e.g., OpenStreetMap).
  Future<void> downloadRegion({
    required String name,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int minZoom,
    required int maxZoom,
    required TileLayer tileLayerOptions,
  }) async {
    try {
      state = state.copyWith(
        isDownloading: true,
        progress: 0.0,
        downloadedTiles: 0,
        totalTiles: 0,
        failedTiles: 0,
        tilesPerSecond: 0.0,
        regionName: name,
        clearError: true,
      );

      final stream = _cacheService.downloadRegion(
        southWest: LatLng(minLat, minLng),
        northEast: LatLng(maxLat, maxLng),
        minZoom: minZoom,
        maxZoom: maxZoom,
        options: tileLayerOptions,
      );

      int downloadedTiles = 0;
      int sizeBytes = 0;

      await for (final progress in stream) {
        downloadedTiles = progress.downloadedTiles;

        state = state.copyWith(
          progress: progress.percentComplete,
          downloadedTiles: progress.downloadedTiles,
          totalTiles: progress.totalTiles,
          failedTiles: progress.failedTiles,
          tilesPerSecond: progress.tilesPerSecond,
        );
      }

      // Estimate size based on average tile size (typical map tiles are ~20KB)
      // This is a rough estimate; actual size would need to be queried from cache
      sizeBytes = downloadedTiles * 20 * 1024;

      // Save region to database
      await _repository.createRegion(
        name: name,
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        minZoom: minZoom,
        maxZoom: maxZoom,
        tileCount: downloadedTiles,
        sizeBytes: sizeBytes,
      );

      // Refresh the regions list and cache stats
      _ref.invalidate(cachedRegionsProvider);
      _ref.invalidate(cacheStatsProvider);

      state = state.copyWith(isDownloading: false);
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: e.toString());
    }
  }

  /// Cancel an ongoing download.
  Future<void> cancelDownload() async {
    await _cacheService.cancelDownload();
    state = const DownloadState();
  }

  /// Pause an ongoing download.
  Future<void> pauseDownload() async {
    await _cacheService.pauseDownload();
  }

  /// Resume a paused download.
  void resumeDownload() {
    _cacheService.resumeDownload();
  }

  /// Check if the current download is paused.
  bool get isPaused => _cacheService.isDownloadPaused;

  /// Reset the download state (clear any errors or completed state).
  void reset() {
    state = const DownloadState();
  }
}

/// Provider for download progress notifier.
final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, DownloadState>((ref) {
      final cacheService = ref.watch(tileCacheServiceProvider);
      final repository = ref.watch(offlineMapRepositoryProvider);
      return DownloadProgressNotifier(cacheService, repository, ref);
    });

/// Provider for a specific cached region by ID.
final cachedRegionByIdProvider = FutureProvider.family<CachedRegion?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(offlineMapRepositoryProvider);
  return repository.getRegionById(id);
});

/// Provider for estimating tile count for a region.
///
/// Takes a tuple-like record of region bounds and zoom levels.
final tileCountEstimateProvider =
    FutureProvider.family<
      int,
      ({
        LatLng southWest,
        LatLng northEast,
        int minZoom,
        int maxZoom,
        TileLayer options,
      })
    >((ref, params) async {
      final service = ref.watch(tileCacheServiceProvider);
      return service.estimateTileCount(
        southWest: params.southWest,
        northEast: params.northEast,
        minZoom: params.minZoom,
        maxZoom: params.maxZoom,
        options: params.options,
      );
    });

/// Notifier for managing cached regions (CRUD operations).
class CachedRegionsNotifier
    extends StateNotifier<AsyncValue<List<CachedRegion>>> {
  final OfflineMapRepository _repository;
  final TileCacheService _cacheService;
  final Ref _ref;

  CachedRegionsNotifier(this._repository, this._cacheService, this._ref)
    : super(const AsyncValue.loading()) {
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    state = const AsyncValue.loading();
    try {
      final regions = await _repository.getAllRegions();
      state = AsyncValue.data(regions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh the regions list.
  Future<void> refresh() async {
    await _loadRegions();
  }

  /// Delete a cached region and its tiles.
  Future<void> deleteRegion(String id) async {
    try {
      // Delete from database
      await _repository.deleteRegion(id);

      // Reload regions
      await _loadRegions();

      // Refresh cache stats
      _ref.invalidate(cacheStatsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update a region's last accessed timestamp.
  Future<void> touchRegion(String id) async {
    await _repository.touchRegion(id);
    await _loadRegions();
  }

  /// Clear all cached tiles and regions.
  Future<void> clearAllCache() async {
    try {
      // Clear tiles from cache service
      await _cacheService.clearCache();

      // Get all regions and delete them
      final regions = await _repository.getAllRegions();
      for (final region in regions) {
        await _repository.deleteRegion(region.id);
      }

      // Reload
      await _loadRegions();
      _ref.invalidate(cacheStatsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for the cached regions notifier.
final cachedRegionsNotifierProvider =
    StateNotifierProvider<
      CachedRegionsNotifier,
      AsyncValue<List<CachedRegion>>
    >((ref) {
      final repository = ref.watch(offlineMapRepositoryProvider);
      final cacheService = ref.watch(tileCacheServiceProvider);
      return CachedRegionsNotifier(repository, cacheService, ref);
    });
