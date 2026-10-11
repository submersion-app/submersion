import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/data/repositories/offline_map_repository.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:uuid/uuid.dart';

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
  ref.invalidateSelfWhen(repository.watchRegionsChanges());
  return repository.getAllRegions();
});

/// Provider for cache statistics.
final cacheStatsProvider = FutureProvider<CacheStats>((ref) async {
  final service = ref.watch(tileCacheServiceProvider);
  return service.getCacheStats();
});

/// The ids of the regions that own their tiles, and so can report a real size
/// and free real bytes when deleted.
///
/// A region missing from this set was downloaded before per-region stores
/// existed: its tiles are commingled in the shared offline store and cannot be
/// told apart from any other legacy region's. The UI uses this to avoid
/// claiming a size it cannot measure.
final regionStoreIdsProvider = FutureProvider<Set<String>>((ref) async {
  final service = ref.watch(tileCacheServiceProvider);
  return service.getRegionStoreIds();
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

  static const _uuid = Uuid();

  /// The region currently downloading.
  ///
  /// Also decides who may write [state]: a superseded download runs on past
  /// the one that replaced it, and only the current download's progress
  /// belongs on screen.
  String? _activeRegionId;

  /// Every download that has been cancelled and has not yet cleaned up.
  ///
  /// Cancelling and finishing both end the progress stream the same way, so
  /// the loop needs to be told which happened. A set rather than one id: a
  /// third download would otherwise displace the first one's mark, and the
  /// first would then take its success path and record a region for the
  /// handful of tiles it had, which is the phantom region this guards against.
  final Set<String> _cancelledRegionIds = {};

  DownloadProgressNotifier(this._cacheService, this._repository, this._ref)
    : super(const DownloadState());

  /// Download tiles for a rectangular region into a store of its own.
  ///
  /// [urlTemplate] is the tile server's URL template (e.g., OpenStreetMap).
  ///
  /// The region's id is minted here, before the download, because the store
  /// that holds its tiles is named after it. Everything after that point is
  /// all-or-nothing: either the region is recorded and its store released, or
  /// the store is deleted. A store left behind would hold tiles no region
  /// could reach and nothing but "Clear all cache" could free.
  Future<void> downloadRegion({
    required String name,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int minZoom,
    required int maxZoom,
    required String urlTemplate,
  }) async {
    final regionId = _uuid.v4();
    // A cancellation belongs to the download it was aimed at. The service
    // cancels the running download when a new one starts, and without being
    // marked cancelled here that first download would fall through to its
    // success path and record a region for the handful of tiles it had
    // managed. Nothing to mark when nothing was running, the ordinary case.
    final superseded = _activeRegionId;
    if (superseded != null) _cancelledRegionIds.add(superseded);
    _activeRegionId = regionId;
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

      final stream = await _cacheService.downloadRegion(
        regionId: regionId,
        southWest: LatLng(minLat, minLng),
        northEast: LatLng(maxLat, maxLng),
        minZoom: minZoom,
        maxZoom: maxZoom,
        urlTemplate: urlTemplate,
      );

      // Cancelling during setup used to be a cancel in name only. The
      // progress card is on screen from the moment this method starts, so the
      // diver can press cancel while the store is still being created, and at
      // that point there is no download instance for the service to cancel.
      // The download would then run to completion, invisibly, and only be
      // thrown away at the end: every tile fetched, every byte of it wasted.
      // Now the download is cancelled as soon as there is something to cancel.
      if (_cancelledRegionIds.contains(regionId)) {
        await _cacheService.discardRegionDownload(regionId);
        _clearStateIfCurrent(regionId);
        return;
      }

      int downloadedTiles = 0;

      await for (final progress in stream) {
        downloadedTiles = progress.downloadedTiles;

        // Cancelling is not instant: the service cancels the download instance
        // and only then cancels the subscription, so a superseded download
        // emits a tick or two on the way out. Those numbers describe a region
        // the diver has moved on from, and on the shared card they appear
        // under the new download's name.
        if (_isCurrent(regionId)) {
          state = state.copyWith(
            progress: progress.percentComplete,
            downloadedTiles: progress.downloadedTiles,
            totalTiles: progress.totalTiles,
            failedTiles: progress.failedTiles,
            tilesPerSecond: progress.tilesPerSecond,
          );
        }
      }

      if (_cancelledRegionIds.contains(regionId)) {
        // A cancelled download used to keep its partial tiles and record a
        // region for them anyway. Now both go.
        await _cacheService.discardRegionDownload(regionId);
        _clearStateIfCurrent(regionId);
        return;
      }

      // A real measurement of the region's own store, which is what per-region
      // stores buy: the size used to be tiles * 20 KiB and had never read the
      // cache.
      final sizeBytes = await _cacheService.measureRegionSize(regionId);

      // Save region to database
      await _repository.createRegion(
        id: regionId,
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

      // The store is reachable through its region now, so it no longer needs
      // protecting from the orphan sweep.
      _cacheService.finishRegionDownload(regionId);

      // Refresh the regions list and cache stats
      _ref.invalidate(cachedRegionsProvider);
      _ref.invalidate(cacheStatsProvider);
      _ref.invalidate(regionStoreIdsProvider);

      if (_isCurrent(regionId)) {
        state = state.copyWith(isDownloading: false);
      }
    } catch (e) {
      // Whatever failed, the store must not outlive the attempt.
      await _discardQuietly(regionId);
      // A superseded download's failure is not the diver's problem: they moved
      // on by starting another one, and putting this error on the new
      // download's card would blame it for something it did not do.
      if (_isCurrent(regionId)) {
        state = state.copyWith(isDownloading: false, error: e.toString());
      }
    } finally {
      // Only if this download is still the current one. A superseded download
      // finishes after the one that replaced it started, and clearing the slot
      // unconditionally would hand the newer download an empty one: the next
      // cancel would mark nothing, so that download would stop transferring
      // and then record a region for the tiles it had, which is the phantom
      // region this branch exists to prevent.
      if (_activeRegionId == regionId) {
        _activeRegionId = null;
      }
      _cancelledRegionIds.remove(regionId);
    }
  }

  /// Whether [regionId] is the download the screen is showing.
  ///
  /// Every write to [state] is gated on this. A superseded download finishes
  /// after the one that replaced it started, and the two share one
  /// [DownloadState]: blanking it on the way out left the newer download with
  /// `isDownloading` false for its whole run, and the progress card is gated
  /// on exactly that, so the diver saw neither progress nor a cancel button.
  bool _isCurrent(String regionId) => _activeRegionId == regionId;

  /// Reset the card, but only for the download that owns it.
  void _clearStateIfCurrent(String regionId) {
    if (_isCurrent(regionId)) state = const DownloadState();
  }

  /// Deletes a failed download's store, keeping the original failure as the
  /// error the diver sees: a cleanup that fails on the way out would otherwise
  /// replace the reason the download failed.
  Future<void> _discardQuietly(String regionId) async {
    try {
      await _cacheService.discardRegionDownload(regionId);
    } catch (_) {
      // Reported through the orphan sweep instead, which will find the store.
    }
  }

  /// Cancel an ongoing download.
  Future<void> cancelDownload() async {
    final active = _activeRegionId;
    if (active != null) _cancelledRegionIds.add(active);
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
  ref.invalidateSelfWhen(repository.watchRegionsChanges());
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
        String urlTemplate,
      })
    >((ref, params) async {
      final service = ref.watch(tileCacheServiceProvider);
      return service.estimateTileCount(
        southWest: params.southWest,
        northEast: params.northEast,
        minZoom: params.minZoom,
        maxZoom: params.maxZoom,
        urlTemplate: params.urlTemplate,
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
  ///
  /// The tiles go first. If removing them fails, the region row survives, so
  /// the diver still has a handle on those bytes and can try again; the other
  /// order would leave tiles on disk that nothing in the app could see, let
  /// alone reclaim.
  ///
  /// For a region downloaded before per-region stores, removing the tiles is a
  /// no-op: they are commingled in the shared offline store with every other
  /// legacy region's and cannot be told apart. The row is still removed.
  Future<void> deleteRegion(String id) async {
    try {
      await _cacheService.deleteRegionTiles(id);

      await _repository.deleteRegion(id);

      // Reload regions
      await _loadRegions();

      // Refresh cache stats
      _ref.invalidate(cacheStatsProvider);
      _ref.invalidate(regionStoreIdsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete region stores whose region is gone.
  ///
  /// A store outlives its region when the app dies mid-download, or when a
  /// delete removed the tiles and then failed before the row. Either way the
  /// tiles are unreachable, which is the condition this whole change exists to
  /// prevent, so the sweep runs whenever the offline maps page is opened.
  ///
  /// Returns how many stores it reclaimed, which the caller needs because the
  /// storage totals on screen were measured before those bytes went away.
  ///
  /// The rows are read through a callback rather than passed in, so the sweep
  /// decides when to read them. A snapshot taken here would be taken before
  /// the sweep lists the stores, and a download finishing in between writes
  /// its row and then drops its in-flight mark: absent from both, its store
  /// would be deleted under a region that exists.
  Future<int> pruneOrphanStores() async {
    return _cacheService.pruneOrphanRegionStores(
      readKnownRegionIds: () async =>
          (await _repository.getAllRegions()).map((r) => r.id).toSet(),
    );
  }

  /// Update a region's last accessed timestamp.
  Future<void> touchRegion(String id) async {
    await _repository.touchRegion(id);
    await _loadRegions();
  }

  /// Clear all cached tiles and regions.
  ///
  /// Region by region, so that a partial failure leaves a coherent state
  /// rather than a plausible-looking lie. Clearing the tiles wholesale first
  /// and the rows afterwards meant that a failure between the two left rows
  /// describing regions whose tiles were already gone: the page would offer
  /// them as regions, report their size as unmeasurable, and warn that
  /// deleting them would not reclaim anything, when in fact there was nothing
  /// left to reclaim.
  ///
  /// Each region is removed the same way a single delete removes one, tiles
  /// before row, so whatever survives a failure is exactly the set whose bytes
  /// are still on disk. The shared stores are reset afterwards, which also
  /// takes any region store no row was pointing at.
  Future<void> clearAllCache() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    try {
      // A running download owns a store with no row yet, so the loop below
      // would walk straight past it and the reset would then delete the store
      // out from under it. Cancelling through the download notifier, rather
      // than the service, is what makes the difference: it marks the download
      // cancelled, so it discards itself instead of finishing and recording a
      // region whose tiles this clear had already removed.
      await _ref.read(downloadProgressProvider.notifier).cancelDownload();

      for (final region in await _repository.getAllRegions()) {
        try {
          await _cacheService.deleteRegionTiles(region.id);
          await _repository.deleteRegion(region.id);
        } catch (e, st) {
          // Kept, not thrown: one locked store must not strand every other
          // region's bytes, which is the whole point of clearing.
          firstError ??= e;
          firstStackTrace ??= st;
        }
      }
    } catch (e, st) {
      firstError ??= e;
      firstStackTrace ??= st;
    }

    try {
      await _cacheService.clearCache();
    } catch (e, st) {
      // Collected like a region's own failure rather than thrown. Throwing
      // here jumped past everything below, so a reset that failed after the
      // rows had gone left the storage card reporting bytes that were not
      // there and no reload to correct it.
      firstError ??= e;
      firstStackTrace ??= st;
    }

    // Whatever failed above, the rows that did go are gone from disk, so what
    // is on screen has to be re-read and re-measured to match.
    await _loadRegions();
    _ref.invalidate(cacheStatsProvider);
    _ref.invalidate(regionStoreIdsProvider);

    if (firstError != null) {
      state = AsyncValue.error(firstError, firstStackTrace ?? StackTrace.empty);
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
