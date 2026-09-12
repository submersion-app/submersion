import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';

// FMTCBrowsingError's constructor is annotated @internal for the FMTC package;
// it is constructed directly here only to drive the error handler in isolation.
// ignore_for_file: invalid_use_of_internal_member

void main() {
  group('store routing', () {
    // The whole point of the two-store split. Submersion used to keep browse
    // caching and downloaded offline regions in one store, and FMTC's
    // removeOldestTilesAboveLimit orders by lastModified across a whole store,
    // so any cap or age sweep would have deleted regions a diver downloaded
    // for a trip. These assertions pin the routing that makes capping safe.
    test('browsing writes to the browse store only', () {
      final strategies = TileCacheService.browseStoreStrategies();

      expect(
        strategies['submersion_tiles_browse'],
        BrowseStoreStrategy.readUpdateCreate,
      );
      expect(strategies['submersion_tiles'], BrowseStoreStrategy.read);
    });

    test('browsing never creates tiles in the offline store', () {
      // If this ever becomes readUpdateCreate, incidental panning would grow
      // the uncapped store without bound and the browse cap would be a lie.
      for (final entry in TileCacheService.browseStoreStrategies().entries) {
        if (entry.key == 'submersion_tiles') {
          expect(
            entry.value,
            BrowseStoreStrategy.read,
            reason: 'the offline store must never be written by browsing',
          );
        }
      }
    });

    test('the offline view reads both stores and writes neither', () {
      final strategies = TileCacheService.offlineStoreStrategies();

      expect(strategies, hasLength(2));
      expect(
        strategies.values,
        everyElement(BrowseStoreStrategy.read),
        reason: 'an offline-only view must not mutate any store',
      );
    });

    test('the two stores are distinct and the offline one keeps its name', () {
      // Renaming submersion_tiles would strand every existing install's
      // downloaded regions, which is the one thing this split must not do.
      final browse = TileCacheService.browseStoreStrategies().keys.toSet();
      final offline = TileCacheService.offlineStoreStrategies().keys.toSet();

      expect(browse, offline);
      expect(browse, contains('submersion_tiles'));
      expect(browse, hasLength(2));
    });

    test('the store name getters match the routing maps', () {
      // Cheap, but the offline getter keeping its historical value is what
      // stops an upgrade from stranding every downloaded region.
      expect(TileCacheService.instance.storeName, 'submersion_tiles');
      expect(
        TileCacheService.instance.browseStoreName,
        'submersion_tiles_browse',
      );
      expect(
        TileCacheService.browseStoreStrategies().keys,
        containsAll([
          TileCacheService.instance.storeName,
          TileCacheService.instance.browseStoreName,
        ]),
      );
    });

    test('an uninitialized service refuses to hand out a store', () {
      // _ensureInitialized now checks both stores, so a half-initialized
      // service cannot leak a null browse store into a tile provider.
      expect(() => TileCacheService.instance.store, throwsStateError);
    });

    test('the browse cap and age are bounded', () {
      expect(TileCacheService.browseStoreMaxTiles, greaterThan(0));
      expect(TileCacheService.browseTileMaxAge, const Duration(days: 30));
    });
  });

  // Flutter's ImageCache keys an FMTC tile on (coordinates, provider), and
  // FMTCTileProvider's equality includes its httpClient by identity. A map
  // that remounts (every dive selected in the master-detail pane rebuilds its
  // header map) builds a fresh provider, so unless two providers compare
  // equal, every tile misses the in-memory cache and blinks back in through
  // FMTC's async lookup even when it was on screen a moment ago.
  //
  // The tile URL is NOT part of that key, so the opposite failure is just as
  // real: if providers for two map styles compared equal, switching styles
  // would paint the previous style's cached bitmap for the same z/x/y.
  group('tile provider identity', () {
    final osm = MapTileConfig.urlTemplate(MapStyle.openStreetMap);
    final esri = MapTileConfig.urlTemplate(MapStyle.esriSatellite);
    const coords = TileCoordinates(4, 7, 12);

    // The key the ImageCache actually stores a tile under.
    Object cacheKey(FMTCTileProvider provider, String urlTemplate) =>
        provider.getImage(coords, TileLayer(urlTemplate: urlTemplate));

    test('two browse providers are equal, so remounted maps hit the cache', () {
      final first = TileCacheService.browseTileProvider(urlTemplate: osm);
      final second = TileCacheService.browseTileProvider(urlTemplate: osm);

      expect(identical(first, second), isFalse);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(cacheKey(first, osm), cacheKey(second, osm));
    });

    test('switching map style never reuses the old style\'s tile', () {
      final before = TileCacheService.browseTileProvider(urlTemplate: osm);
      final after = TileCacheService.browseTileProvider(urlTemplate: esri);

      expect(before, isNot(after));
      expect(cacheKey(before, osm), isNot(cacheKey(after, esri)));
    });

    test('an uninitialized cache hands maps no provider', () {
      // Every map passes this straight to TileLayer.tileProvider, where null
      // means flutter_map's own network provider: a cache that failed to
      // start must still leave the maps working.
      expect(
        TileCacheService.instance.tileProviderFor(urlTemplate: osm),
        isNull,
      );
    });

    test('a different loading strategy is a different cache key', () {
      expect(
        TileCacheService.browseTileProvider(urlTemplate: osm),
        isNot(
          TileCacheService.browseTileProvider(
            urlTemplate: osm,
            loadingStrategy: BrowseLoadingStrategy.cacheOnly,
          ),
        ),
      );
    });

    test(
      'offline providers are equal per style and distinct across styles',
      () {
        expect(
          TileCacheService.offlineTileProvider(urlTemplate: osm),
          TileCacheService.offlineTileProvider(urlTemplate: osm),
        );
        expect(
          TileCacheService.offlineTileProvider(urlTemplate: osm),
          isNot(TileCacheService.offlineTileProvider(urlTemplate: esri)),
        );
      },
    );
  });

  // Issue #1403: deleting a region used to free nothing, because FMTC can only
  // delete a whole store and every region shared one. Giving each downloaded
  // region its own store is what makes deletion expressible at all.
  group('per-region stores', () {
    test('a region store name is derived from the region id', () {
      expect(
        TileCacheService.regionStoreName('abc-123'),
        'submersion_region_abc-123',
      );
      expect(
        TileCacheService.regionIdFromStoreName('submersion_region_abc-123'),
        'abc-123',
      );
    });

    test('the shared stores are never read as region stores', () {
      // A prefix collision here would make the orphan sweep delete every
      // legacy tile in the app.
      for (final shared in const [
        'submersion_tiles',
        'submersion_tiles_browse',
      ]) {
        expect(TileCacheService.regionIdFromStoreName(shared), isNull);
      }
      expect(
        TileCacheService.regionIdFromStoreName('submersion_region_'),
        isNull,
        reason: 'an empty id is not a region',
      );
    });

    test('browsing reads other stores and never writes them', () {
      // The single most important assertion in this file. If unspecified
      // stores ever became writable, panning the map would grow every
      // downloaded region without bound and its measured size would drift.
      expect(TileCacheService.otherStoresStrategy, BrowseStoreStrategy.read);
    });

    test('totals count this app\'s stores and no others', () {
      // The FMTC root is shared, and the totals sit next to a button that only
      // clears these. Counting a store that button cannot touch would put
      // bytes on screen that nothing on the page can free.
      for (final ours in const [
        'submersion_tiles',
        'submersion_tiles_browse',
        'submersion_region_abc',
      ]) {
        expect(TileCacheService.isOwnStoreName(ours), isTrue, reason: ours);
      }
      for (final theirs in const [
        'someone_elses_store',
        'submersion_region_',
        'tiles',
      ]) {
        expect(
          TileCacheService.isOwnStoreName(theirs),
          isFalse,
          reason: theirs,
        );
      }
    });

    test('orphan selection keeps every store it cannot prove is garbage', () {
      final orphans = TileCacheService.orphanRegionStores(
        availableStores: const [
          'submersion_tiles',
          'submersion_tiles_browse',
          'submersion_region_kept',
          'submersion_region_downloading',
          'submersion_region_orphan',
          'someone_elses_store',
        ],
        knownRegionIds: {'kept'},
        inFlightRegionIds: {'downloading'},
      );

      expect(orphans, {'submersion_region_orphan'});
    });

    test('cache totals do not decay as regions are added', () {
      // FMTC records a miss against every store it was allowed to read, so a
      // sum would multiply one uncached tile by the number of stores and drive
      // the reported hit rate to nothing as a diver downloads regions.
      final stats = TileCacheService.aggregateCacheStats(const [
        (size: 100.0, length: 10, hits: 4, misses: 200),
        (size: 50.0, length: 5, hits: 1, misses: 200),
        (size: 25.0, length: 2, hits: 0, misses: 30),
      ]);

      expect(stats.tileCount, 17);
      expect(stats.sizeKiB, 175.0);
      expect(stats.hits, 5);
      expect(stats.misses, 200);
    });

    test('an empty cache reports nothing rather than dividing by zero', () {
      final stats = TileCacheService.aggregateCacheStats(const []);

      expect(stats.tileCount, 0);
      expect(stats.misses, 0);
      expect(stats.hitRate, 0);
    });

    test('orphan selection never returns a shared or foreign store', () {
      final orphans = TileCacheService.orphanRegionStores(
        availableStores: const [
          'submersion_tiles',
          'submersion_tiles_browse',
          'someone_elses_store',
        ],
        knownRegionIds: const {},
        inFlightRegionIds: const {},
      );

      expect(orphans, isEmpty);
    });
  });

  group('TileCacheService.handleTileError', () {
    // Returns the next LogEntry emitted on the shared logger stream while
    // [action] runs. The subscription is established before [action] so the
    // handler's synchronous emission is captured.
    Future<LogEntry> logFrom(void Function() action) {
      final next = LoggerService.logStream.first;
      action();
      return next;
    }

    test('returns null so a failed tile renders blank instead of throwing', () {
      final result = TileCacheService.handleTileError(
        FMTCBrowsingError(
          type: FMTCBrowsingErrorType.noConnectionDuringFetch,
          networkUrl: 'https://tile.example/0/0/0.png',
          storageSuitableUID: 'uid',
        ),
      );

      expect(result, isNull);
    });

    test('logs an offline cache miss at info with the type and url', () async {
      final entry = await logFrom(() {
        TileCacheService.handleTileError(
          FMTCBrowsingError(
            type: FMTCBrowsingErrorType.noConnectionDuringFetch,
            networkUrl: 'https://tile.example/4/5/6.png',
            storageSuitableUID: 'uid',
          ),
        );
      });

      expect(entry.level, LogLevel.info);
      expect(
        entry.message,
        allOf(
          contains('Tile load failed [noConnectionDuringFetch]'),
          contains('url=https://tile.example/4/5/6.png'),
        ),
      );
    });

    test(
      'logs a non-200 response at warning with status and content type',
      () async {
        final entry = await logFrom(() {
          TileCacheService.handleTileError(
            FMTCBrowsingError(
              type: FMTCBrowsingErrorType.negativeFetchResponse,
              networkUrl: 'https://tile.openstreetmap.org/1/2/3.png',
              storageSuitableUID: 'uid',
              response: http.Response(
                'blocked',
                418,
                headers: const {'content-type': 'text/html'},
              ),
            ),
          );
        });

        expect(entry.level, LogLevel.warning);
        expect(
          entry.message,
          allOf(
            contains('httpStatus=418'),
            contains('contentType=text/html'),
            contains('bodyBytes=7'), // 'blocked' is 7 bytes
          ),
        );
      },
    );

    test(
      'logs an unexpected transport error at warning with the cause',
      () async {
        final entry = await logFrom(() {
          TileCacheService.handleTileError(
            FMTCBrowsingError(
              type: FMTCBrowsingErrorType.unknownFetchException,
              networkUrl: 'https://tile.openstreetmap.org/7/8/9.png',
              storageSuitableUID: 'uid',
              originalError: const FormatException('handshake boom'),
            ),
          );
        });

        expect(entry.level, LogLevel.warning);
        expect(
          entry.message,
          allOf(contains('cause=FormatException'), contains('handshake boom')),
        );
      },
    );

    test('never rethrows when the cause toString throws', () async {
      Object? result;
      final entry = await logFrom(() {
        result = TileCacheService.handleTileError(
          FMTCBrowsingError(
            type: FMTCBrowsingErrorType.unknownFetchException,
            networkUrl: 'https://tile.example/1/1/1.png',
            storageSuitableUID: 'uid',
            originalError: _ThrowingToString(),
          ),
        );
      });

      expect(result, isNull); // handler degraded instead of propagating
      expect(entry.level, LogLevel.warning);
      expect(entry.message, contains('cause=_ThrowingToString'));
    });
  });

  group('a cache that never initialized', () {
    // The app runs on regardless: startup swallows an initialize() failure
    // with a log line, so every FMTC-backed call throws for the rest of the
    // session. Deleting a region removes its tiles before its row, so a throw
    // here would leave the diver unable to delete any region at all, legacy
    // ones included, where there is no store and nothing to free.
    test('has no region tiles to delete, rather than an error', () async {
      await expectLater(
        TileCacheService.instance.deleteRegionTiles('any-region'),
        completes,
      );
    });

    test('still refuses the calls that need a live store', () {
      // The no-op above is scoped to tile deletion. Anything that would hand
      // back a store must keep failing loudly.
      expect(() => TileCacheService.instance.store, throwsStateError);
    });
  });
}

/// A cause whose `toString` throws, used to verify
/// [TileCacheService.handleTileError] degrades safely rather than letting the
/// error escape the handler.
class _ThrowingToString {
  @override
  String toString() => throw StateError('toString boom');
}
