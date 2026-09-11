import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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
/// final tileProvider = TileCacheService.instance.getTileProvider(
///   urlTemplate: ref.watch(mapTileUrlProvider),
/// );
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

  /// Prefix of a downloaded region's own store.
  ///
  /// FMTC 10 can delete a whole store or tiles older than a date, and nothing
  /// in between: there is no call that says "remove the tiles inside this
  /// rectangle". So a region only becomes deletable by being a store. Every
  /// region downloaded from this version on gets one of these, named for the
  /// region's id, and [deleteRegionTiles] is then a store delete.
  ///
  /// Regions downloaded before this change have their tiles commingled in
  /// [_offlineStoreName] with old browse tiles, and there is no way to tell
  /// after the fact which tile belongs to which region. Those keep the old
  /// behaviour: deleting one frees nothing, and the UI does not claim a size
  /// it cannot measure for them.
  static const String regionStorePrefix = 'submersion_region_';

  static final LoggerService _log = LoggerService.forClass(TileCacheService);

  bool _initialized = false;
  FMTCStore? _store;
  FMTCStore? _browseStore;
  StreamSubscription<DownloadProgress>? _activeDownloadSubscription;
  Object? _activeDownloadId;

  /// The stream handed to the caller of [downloadRegion].
  ///
  /// Held because it is closed from the subscription's `onDone`, and
  /// [cancelDownload] cancels that subscription: cancelling a subscription
  /// suppresses its callbacks, so a cancel that lands before FMTC's own
  /// progress stream closes would leave this open forever and the caller
  /// awaiting it would never resume.
  StreamController<TileDownloadProgress>? _activeDownloadController;

  /// The store the active download is filling.
  ///
  /// FMTC resolves a download by its instance id through a registry that is
  /// global to the process, so any store handle would in fact cancel it. That
  /// is an internal detail of the package, and reaching for the shared offline
  /// store to cancel a download running against a region store reads like a
  /// bug even while it works. Holding the real one costs nothing and says what
  /// is meant.
  FMTCStore? _activeDownloadStore;

  /// The region the active download belongs to.
  ///
  /// [_activeDownloadId] alone says a download is running but not whose it is,
  /// and cleanup for an abandoned download can arrive after a new one has
  /// started. Without this, discarding the old one would cancel the new one.
  String? _activeDownloadRegionId;

  /// Regions whose store exists but whose database row does not yet, because
  /// the download is still running or its row is still being written.
  ///
  /// [pruneOrphanRegionStores] deletes a region store with no row, which is
  /// exactly what an in-flight download looks like from the outside, so it
  /// has to be told to leave these alone.
  final Set<String> _inFlightRegionIds = {};

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

  /// Whether a store belongs to this app.
  ///
  /// The FMTC root is shared, so [FMTCRoot.stats] can list stores this feature
  /// did not create. Totals are shown next to a "Clear all cache" button that
  /// only touches these, so counting anything else would put bytes on screen
  /// that the button beside them cannot free.
  static bool isOwnStoreName(String storeName) =>
      storeName == _offlineStoreName ||
      storeName == _browseStoreName ||
      regionIdFromStoreName(storeName) != null;

  /// The store that holds the tiles of the region with this id.
  static String regionStoreName(String regionId) =>
      '$regionStorePrefix$regionId';

  /// The region a store belongs to, or `null` if the store is not a region
  /// store.
  ///
  /// [_offlineStoreName] and [_browseStoreName] deliberately fall outside the
  /// prefix: reading either of them as a region would let the orphan sweep
  /// delete every legacy tile in the app.
  static String? regionIdFromStoreName(String storeName) =>
      storeName.startsWith(regionStorePrefix) &&
          storeName.length > regionStorePrefix.length
      ? storeName.substring(regionStorePrefix.length)
      : null;

  /// How a map treats the stores it does not name: read them, never write.
  ///
  /// This is what lets a map view read every downloaded region without
  /// enumerating them, so the tile provider's configuration stays a constant
  /// as regions come and go.
  ///
  /// It must stay [BrowseStoreStrategy.read]. A write strategy here would let
  /// incidental panning add tiles to every downloaded region, which would grow
  /// them without bound and make each region's measured size a running total
  /// of wherever the diver happened to pan.
  static const BrowseStoreStrategy otherStoresStrategy =
      BrowseStoreStrategy.read;

  /// The region stores that no longer belong to any region, and so hold tiles
  /// nothing can reach.
  ///
  /// A store outlives its row when the app dies between creating the store and
  /// writing the region, or when a delete removes the tiles and then fails.
  /// Pure and [visibleForTesting]: this is the decision worth asserting, while
  /// the deletion around it needs a live backend.
  @visibleForTesting
  static Set<String> orphanRegionStores({
    required Iterable<String> availableStores,
    required Set<String> knownRegionIds,
    required Set<String> inFlightRegionIds,
  }) {
    final orphans = <String>{};
    for (final storeName in availableStores) {
      final regionId = regionIdFromStoreName(storeName);
      if (regionId == null) continue;
      if (knownRegionIds.contains(regionId)) continue;
      if (inFlightRegionIds.contains(regionId)) continue;
      orphans.add(storeName);
    }
    return orphans;
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
  ///       tileProvider: TileCacheService.instance.getTileProvider(
  ///         urlTemplate: ref.watch(mapTileUrlProvider),
  ///       ),
  ///     );
  ///   }
  /// }
  /// ```
  FMTCTileProvider getTileProvider({
    required String urlTemplate,
    // coverage:ignore-start
    BrowseLoadingStrategy loadingStrategy = BrowseLoadingStrategy.cacheFirst,
  }) {
    _ensureInitialized();
    return browseTileProvider(
      urlTemplate: urlTemplate,
      loadingStrategy: loadingStrategy,
    );
    // coverage:ignore-end
  }

  /// The browse provider for [urlTemplate], or null until [initialize] has
  /// succeeded.
  ///
  /// This is what a map hands to `TileLayer.tileProvider`: null there means
  /// flutter_map's own network provider, so a cache that failed to start
  /// leaves the maps working, just uncached.
  FMTCTileProvider? tileProviderFor({required String urlTemplate}) =>
      isInitialized ? getTileProvider(urlTemplate: urlTemplate) : null;

  /// One HTTP client per tile URL template, shared by every provider this
  /// service builds for that template.
  ///
  /// FMTCTileProvider's equality compares its client by identity, and that
  /// equality is half of the ImageCache key for every tile. Left to itself the
  /// constructor creates a new client per provider, so no two providers were
  /// ever equal and a remounted map (the dive header, on every selection)
  /// missed the in-memory cache for tiles it had just shown.
  ///
  /// The key does not include the tile URL, so one client for everything
  /// would make every map style's provider equal, and switching style would
  /// paint the previous style's cached bitmap for the same z/x/y. A client
  /// per template keeps providers equal within a style and distinct across
  /// styles. Bounded by the handful of map styles, and each lives for the
  /// process: FMTC only closes a client it created itself, so disposing a map
  /// leaves these open for the next.
  static final Map<String, http.Client> _httpClients = {};

  static http.Client _httpClientFor(String urlTemplate) => _httpClients
      .putIfAbsent(urlTemplate, () => IOClient(HttpClient()..userAgent = null));

  /// The provider [getTileProvider] hands out, without the initialization
  /// guard, so its identity can be asserted without an ObjectBox backend.
  @visibleForTesting
  static FMTCTileProvider browseTileProvider({
    required String urlTemplate,
    BrowseLoadingStrategy loadingStrategy = BrowseLoadingStrategy.cacheFirst,
  }) => FMTCTileProvider(
    stores: browseStoreStrategies(),
    otherStoresStrategy: otherStoresStrategy,
    loadingStrategy: loadingStrategy,
    errorHandler: handleTileError,
    httpClient: _httpClientFor(urlTemplate),
  );

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

  // coverage:ignore-start
  /// Get a tile provider configured for offline-only usage.
  ///
  /// This provider will only use cached tiles and will not make network
  /// requests.
  FMTCTileProvider getOfflineTileProvider({required String urlTemplate}) {
    _ensureInitialized();
    return offlineTileProvider(urlTemplate: urlTemplate);
  }
  // coverage:ignore-end

  /// The provider [getOfflineTileProvider] hands out, without the
  /// initialization guard, so its identity can be asserted in tests.
  @visibleForTesting
  static FMTCTileProvider offlineTileProvider({required String urlTemplate}) =>
      FMTCTileProvider(
        stores: offlineStoreStrategies(),
        otherStoresStrategy: otherStoresStrategy,
        loadingStrategy: BrowseLoadingStrategy.cacheOnly,
        httpClient: _httpClientFor(urlTemplate),
      );

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

  /// Download tiles for a rectangular region into that region's own store.
  ///
  /// [regionId] is the id the region will be recorded under, so the caller
  /// has to mint it before calling. The store is created here and belongs to
  /// the region from this moment: either the caller records the region and
  /// calls [finishRegionDownload], or it calls [discardRegionDownload] and the
  /// partial tiles go with it. Until one of those happens the store is
  /// protected from [pruneOrphanRegionStores].
  ///
  /// Returns a stream of [TileDownloadProgress] updates.
  ///
  /// Use [cancelDownload] to cancel an ongoing download.
  Future<Stream<TileDownloadProgress>> downloadRegion({
    required String regionId,
    required LatLng southWest,
    required LatLng northEast,
    required int minZoom,
    required int maxZoom,
    required TileLayer options,
    int parallelThreads = 5,
    bool skipExistingTiles = true,
  }) async {
    // coverage:ignore-start
    _ensureInitialized();

    // Cancel any existing download, through the full teardown rather than a
    // partial one. Cancelling the subscription alone suppresses its onDone,
    // which is what would have closed the stream the previous caller is still
    // awaiting: it would wait on it forever, and the region it was downloading
    // would stay marked in-flight, protecting its store from the sweep for the
    // life of the process. Awaited so the old download is fully torn down
    // before this one takes over its bookkeeping.
    await cancelDownload();

    final bounds = LatLngBounds(southWest, northEast);
    final region = RectangleRegion(bounds);
    final downloadableRegion = region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: options,
    );

    // Protected from the orphan sweep from here until the caller records the
    // region or discards the download. Every exit path below releases it: a
    // region left marked in-flight is one pruneOrphanRegionStores skips
    // forever, so a store half-created here would become exactly the
    // unreachable bytes per-region stores exist to prevent.
    _inFlightRegionIds.add(regionId);

    try {
      final regionStore = FMTCStore(regionStoreName(regionId));
      await regionStore.manage.create();

      _activeDownloadId = DateTime.now().millisecondsSinceEpoch;
      _activeDownloadRegionId = regionId;
      _activeDownloadStore = regionStore;

      final streams = regionStore.download.startForeground(
        region: downloadableRegion,
        parallelThreads: parallelThreads,
        // Skips nothing in practice, and cannot: it consults only the store
        // being written, and that store is new every time. While every region
        // shared one store, a download overlapping an earlier one reused its
        // tiles; now the overlap is fetched from the tile server again and
        // held twice. That is the price of being able to delete one region's
        // tiles at all, which FMTC can only do by deleting a whole store, and
        // it is why an overlapping tile counts once per region that holds it.
        skipExistingTiles: skipExistingTiles,
        instanceId: _activeDownloadId!,
      );

      final controller = StreamController<TileDownloadProgress>();
      _activeDownloadController = controller;

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
          _activeDownloadRegionId = null;
          _activeDownloadStore = null;
          _activeDownloadSubscription = null;
          _activeDownloadController = null;
          controller.close();
        },
      );

      return controller.stream;
    } catch (_) {
      // Everything this call set, unset. A failed setup that left
      // _activeDownloadId behind would leave the service believing a download
      // was running: the next cancel would address an instance that never
      // existed, and isDownloadPaused would answer for it.
      _inFlightRegionIds.remove(regionId);
      final controller = _activeDownloadController;
      if (controller != null && !controller.isClosed) {
        unawaited(controller.close());
      }
      _activeDownloadId = null;
      _activeDownloadRegionId = null;
      _activeDownloadStore = null;
      _activeDownloadController = null;
      await _activeDownloadSubscription?.cancel();
      _activeDownloadSubscription = null;
      rethrow;
    }
    // coverage:ignore-end
  }

  /// The size in bytes of the tiles belonging to [regionId].
  ///
  /// A real measurement of the region's own store, which replaced a flat
  /// 20 KiB per tile that had never read the cache. Real tiles vary by about
  /// an order of magnitude with zoom and terrain, so the constant was wrong
  /// for essentially every region.
  ///
  /// Returns 0 for a region with no store of its own, which is every region
  /// downloaded before per-region stores existed. Callers must distinguish
  /// that from a measured zero: see [getRegionStoreIds].
  Future<int> measureRegionSize(String regionId) async {
    // coverage:ignore-start
    _ensureInitialized();
    final store = FMTCStore(regionStoreName(regionId));
    if (!await store.manage.ready) return 0;
    final stats = await store.stats.all;
    // FMTC reports KiB.
    return (stats.size * 1024).round();
    // coverage:ignore-end
  }

  /// Delete the tiles belonging to [regionId].
  ///
  /// A no-op for a region with no store of its own: its tiles are commingled
  /// with every other legacy region's in [_offlineStoreName] and cannot be
  /// separated. Only "Clear all cache" reclaims those.
  Future<void> deleteRegionTiles(String regionId) async {
    // A cache that never opened has no store to delete, and the region's row
    // has to stay removable. Startup carries on after an initialize() failure
    // with only a log line, and deleting a region now removes its tiles before
    // its row, so throwing here would make every region undeletable for the
    // rest of the session, a legacy region that owns no store included.
    // Anything actually on disk keeps until the sweep reclaims it on a later
    // run, once the cache does open.
    if (!_initialized) {
      _inFlightRegionIds.remove(regionId);
      _log.warning(
        'Tile cache never initialized; region $regionId has no store to delete',
      );
      return;
    }
    // coverage:ignore-start
    _ensureInitialized();
    final store = FMTCStore(regionStoreName(regionId));
    try {
      if (await store.manage.ready) {
        await store.manage.delete();
        _log.info('Deleted tile store for region $regionId');
      }
    } finally {
      // Released even when the delete failed, and especially then: the
      // protection exists only to shield a download in progress, and holding
      // it past a failure is what would stop the sweep from ever reclaiming
      // the store that is still sitting there.
      _inFlightRegionIds.remove(regionId);
    }
    // coverage:ignore-end
  }

  /// Abandon a download: cancel it, then delete the store it was filling.
  ///
  /// Without this a cancelled or failed download would leave its partial
  /// tiles on disk with no region to reach them by, which is the leak this
  /// whole change is about.
  Future<void> discardRegionDownload(String regionId) async {
    // coverage:ignore-start
    // Only if this region still owns the running download. A cancelled
    // download's cleanup runs after its progress stream drains, by which time
    // the diver may already have started another region: cancelling
    // unconditionally would kill that new download, and it would then be
    // recorded as a complete region holding whatever few tiles it had managed.
    if (_activeDownloadRegionId == regionId) {
      await cancelDownload();
    }
    await deleteRegionTiles(regionId);
    // coverage:ignore-end
  }

  /// Release the protection [downloadRegion] took, once the region's row
  /// exists and the store can be reached through it.
  void finishRegionDownload(String regionId) {
    _inFlightRegionIds.remove(regionId);
  }

  /// The ids of the regions that own their tiles.
  ///
  /// A region outside this set was downloaded before per-region stores, so
  /// its size cannot be measured and its tiles cannot be freed individually.
  Future<Set<String>> getRegionStoreIds() async {
    // coverage:ignore-start
    _ensureInitialized();
    final stores = await FMTCRoot.stats.storesAvailable;
    return stores
        .map((s) => regionIdFromStoreName(s.storeName))
        .nonNulls
        .toSet();
    // coverage:ignore-end
  }

  /// Delete region stores that no longer belong to any region.
  ///
  /// [readKnownRegionIds] must yield every region currently recorded; anything
  /// else carrying the region prefix is unreachable and is deleted. Stores that
  /// are not ours are never touched.
  ///
  /// It is a callback rather than a set because the order of the reads decides
  /// whether this is safe. A download that finishes while the sweep is running
  /// writes its row and only then releases its in-flight mark, so the rows
  /// must be read after that mark has been pinned: read the other way round,
  /// the sweep sees neither and deletes the store of a region that exists,
  /// leaving a row with a size and no tiles.
  ///
  /// Returns how many stores it deleted, so a caller showing storage totals
  /// knows whether they still describe what is on disk.
  Future<int> pruneOrphanRegionStores({
    required Future<Set<String>> Function() readKnownRegionIds,
  }) async {
    // coverage:ignore-start
    _ensureInitialized();
    final available = await FMTCRoot.stats.storesAvailable;
    // Copied, not aliased: the live set keeps changing, and passing it through
    // would have it read after the rows below rather than before them.
    final inFlightRegionIds = Set<String>.of(_inFlightRegionIds);
    final knownRegionIds = await readKnownRegionIds();
    final orphans = orphanRegionStores(
      availableStores: available.map((s) => s.storeName),
      knownRegionIds: knownRegionIds,
      inFlightRegionIds: inFlightRegionIds,
    );
    var deleted = 0;
    for (final storeName in orphans) {
      // Per store, so one locked or corrupt store cannot stop the others from
      // being reclaimed. The loop order is stable, so an aborting sweep would
      // hide every orphan behind the same failing one on every future run.
      try {
        await FMTCStore(storeName).manage.delete();
        deleted++;
        _log.info('Deleted orphaned region tile store $storeName');
      } catch (e, st) {
        _log.warning(
          'Could not delete orphaned region store $storeName: $e',
          stackTrace: st,
        );
      }
    }
    return deleted;
    // coverage:ignore-end
  }

  /// Cancel an ongoing download.
  Future<void> cancelDownload() async {
    if (_activeDownloadId != null) {
      await _downloadControls.cancel(instanceId: _activeDownloadId!);
      await _activeDownloadSubscription?.cancel();
      // Closed here rather than left to onDone, which the cancel above has
      // just made unreachable. Without this the caller's `await for` never
      // ends: the download would appear to run forever, its region would stay
      // marked in-flight, and the sweep would protect its store indefinitely.
      // Not awaited, because a controller nobody subscribed to only completes
      // its close once something drains it.
      final controller = _activeDownloadController;
      if (controller != null && !controller.isClosed) {
        unawaited(controller.close());
      }
      _activeDownloadId = null;
      _activeDownloadRegionId = null;
      _activeDownloadStore = null;
      _activeDownloadSubscription = null;
      _activeDownloadController = null;
    }
  }

  /// The download API of whichever store owns the running download.
  ///
  /// Falls back to the shared store only when nothing is running, where the
  /// call is a no-op either way.
  StoreDownload get _downloadControls =>
      (_activeDownloadStore ?? _store!).download;

  /// Pause an ongoing download.
  Future<void> pauseDownload() async {
    if (_activeDownloadId != null) {
      await _downloadControls.pause(instanceId: _activeDownloadId!);
    }
  }

  /// Resume a paused download.
  void resumeDownload() {
    if (_activeDownloadId != null) {
      _downloadControls.resume(instanceId: _activeDownloadId!);
    }
  }

  /// Check if a download is currently paused.
  bool get isDownloadPaused {
    if (_activeDownloadId == null) return false;
    return _downloadControls.isPaused(instanceId: _activeDownloadId!);
  }

  /// Get statistics about the tile cache.
  ///
  /// Covers every store, region stores included: they hold the bulk of the
  /// bytes once regions are downloaded, and a total that skipped them would
  /// under-report exactly the storage this is shown to explain.
  Future<CacheStats> getCacheStats() async {
    // coverage:ignore-start
    _ensureInitialized();

    final perStore = <({double size, int length, int hits, int misses})>[];
    for (final store in await FMTCRoot.stats.storesAvailable) {
      if (!isOwnStoreName(store.storeName)) continue;
      // Skipped rather than fatal. A store can disappear between listing and
      // reading it, because the orphan sweep runs on this very page and
      // deletes stores while this total is being taken; a store that no longer
      // exists contributes nothing anyway. A locked one under-reports, which
      // is still a better answer than an error card in place of the figure.
      try {
        perStore.add(await store.stats.all);
      } catch (e, st) {
        _log.warning(
          'Skipped unreadable tile store ${store.storeName} in cache '
          'totals: $e',
          stackTrace: st,
        );
      }
    }
    return aggregateCacheStats(perStore);
    // coverage:ignore-end
  }

  /// Roll per-store statistics into one figure for the whole cache.
  ///
  /// Tiles and bytes add up, because a tile belongs to one store. Hits and
  /// misses do not, and the difference matters now that the number of stores
  /// grows with the number of downloaded regions:
  ///
  /// * FMTC records a miss against *every* store it was allowed to read, so
  ///   one uncached tile increments as many counters as there are stores.
  ///   Summing those would make the miss count, and with it the hit rate,
  ///   deteriorate as a diver downloads more regions, which has nothing to do
  ///   with how the cache is performing. Each store's own count is the number
  ///   of misses over its lifetime, so the largest is the best available
  ///   estimate of the total.
  /// * A hit is recorded only against the stores that actually held the tile,
  ///   so hits are summed. A tile present in two overlapping regions counts
  ///   twice, which is the one inaccuracy left here and is bounded by how much
  ///   the diver's regions overlap.
  ///
  /// Pure and [visibleForTesting]: the arithmetic is worth pinning, the
  /// backend calls around it are not testable.
  @visibleForTesting
  static CacheStats aggregateCacheStats(
    Iterable<({double size, int length, int hits, int misses})> perStore,
  ) {
    var tileCount = 0;
    var sizeKiB = 0.0;
    var hits = 0;
    var misses = 0;
    for (final stats in perStore) {
      tileCount += stats.length;
      sizeKiB += stats.size;
      hits += stats.hits;
      if (stats.misses > misses) misses = stats.misses;
    }
    return CacheStats(
      tileCount: tileCount,
      sizeKiB: sizeKiB,
      hits: hits,
      misses: misses,
    );
  }

  /// Clear all cached tiles.
  ///
  /// Resets the two shared stores and deletes every region store outright.
  /// The caller is expected to delete the region rows alongside this.
  Future<void> clearCache() async {
    // coverage:ignore-start
    _ensureInitialized();
    await _store!.manage.reset();
    await _browseStore!.manage.reset();
    // Guarded per store for the same reason as the orphan sweep: one locked
    // store must not keep the rest of the cache on disk. The failures are
    // collected rather than swallowed, because "Clear all cache" that silently
    // freed only some of it would be the same false claim this change removes.
    final failed = <String>[];
    for (final store in await FMTCRoot.stats.storesAvailable) {
      if (regionIdFromStoreName(store.storeName) == null) continue;
      try {
        await store.manage.delete();
      } catch (e, st) {
        failed.add(store.storeName);
        _log.warning(
          'Could not delete region store ${store.storeName}: $e',
          stackTrace: st,
        );
      }
    }
    _inFlightRegionIds.clear();
    if (failed.isNotEmpty) {
      throw StateError(
        'Could not delete ${failed.length} region tile '
        '${failed.length == 1 ? "store" : "stores"}: ${failed.join(", ")}',
      );
    }
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
