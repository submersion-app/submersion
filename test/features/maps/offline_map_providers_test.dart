import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/data/repositories/offline_map_repository.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';

import '../../helpers/test_database.dart';

/// Records every tile-store call the providers make, so the orchestration that
/// issue #1403 is about (tiles removed before the row, a cancelled download
/// leaving neither tiles nor a row) can be asserted without an ObjectBox
/// backend, which `flutter test` has no way to stand up.
class _FakeTileCache implements TileCacheService {
  final calls = <String>[];

  /// The controller backing the most recent download. Recreated per call, so
  /// a test can run a second download after cancelling the first.
  StreamController<TileDownloadProgress> progress =
      StreamController<TileDownloadProgress>();

  int measuredBytes = 0;
  Object? deleteTilesError;

  /// Regions whose tile deletion fails, for asserting that a partial clear
  /// keeps exactly the rows whose bytes are still there.
  final Set<String> undeletableRegionIds = {};
  Object? downloadError;
  Object? clearCacheError;

  /// When set, [downloadRegion] waits on this before handing back its stream,
  /// standing in for the store creation the real service awaits there.
  Completer<void>? setupGate;

  /// Whether a download instance exists yet. The real service has nothing to
  /// cancel until `startForeground` has run, and cancelling before that is a
  /// no-op there too; without modelling that, a test cannot tell an early
  /// cancellation from a late one.
  bool downloadStarted = false;
  Set<String> regionStoreIds = {};

  @override
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
    calls.add('download:$regionId');
    // Mirrors the service, which tears down any running download before
    // starting the next one, closing the stream its caller is still awaiting.
    if (downloadStarted) await cancelDownload();
    final gate = setupGate;
    if (gate != null) await gate.future;
    final error = downloadError;
    if (error != null) throw error;
    if (progress.isClosed) {
      progress = StreamController<TileDownloadProgress>();
    }
    downloadStarted = true;
    return progress.stream;
  }

  @override
  Future<int> measureRegionSize(String regionId) async {
    calls.add('measure:$regionId');
    return measuredBytes;
  }

  @override
  Future<void> deleteRegionTiles(String regionId) async {
    calls.add('deleteTiles:$regionId');
    final error = deleteTilesError;
    if (error != null) throw error;
    if (undeletableRegionIds.contains(regionId)) {
      throw StateError('store for $regionId is locked');
    }
  }

  @override
  Future<void> discardRegionDownload(String regionId) async {
    calls.add('discard:$regionId');
  }

  @override
  void finishRegionDownload(String regionId) {
    calls.add('finish:$regionId');
  }

  @override
  Future<Set<String>> getRegionStoreIds() async {
    calls.add('storeIds');
    return regionStoreIds;
  }

  int prunedStores = 0;

  /// Runs after the sweep has listed the stores and before it reads the region
  /// rows, standing in for a download that finishes while the sweep is in
  /// flight. The row it writes must still count as known.
  Future<void> Function()? beforeReadingRegions;

  @override
  Future<int> pruneOrphanRegionStores({
    required Future<Set<String>> Function() readKnownRegionIds,
  }) async {
    await beforeReadingRegions?.call();
    final known = (await readKnownRegionIds()).toList()..sort();
    calls.add('prune:${known.join(",")}');
    return prunedStores;
  }

  /// Holds the cancellation open partway through, modelling the service: it
  /// awaits the download instance's own cancel before it cancels the
  /// subscription and closes the controller, so a tick can still arrive in
  /// between and reach a caller that is still in its `await for`.
  Completer<void>? cancelGate;

  @override
  Future<void> cancelDownload() async {
    calls.add('cancel');
    // Nothing to cancel until the download has started, exactly as in the
    // service, where the instance id is not assigned until then.
    if (!downloadStarted) return;
    final gate = cancelGate;
    if (gate != null) await gate.future;
    // Not awaited: close() on a controller nobody listened to completes only
    // once a subscriber drains it.
    if (!progress.isClosed) unawaited(progress.close());
  }

  int statsReads = 0;

  @override
  Future<CacheStats> getCacheStats() async {
    statsReads++;
    return const CacheStats(tileCount: 0, sizeKiB: 0, hits: 0, misses: 0);
  }

  @override
  Future<void> clearCache() async {
    calls.add('clearCache');
    final error = clearCacheError;
    if (error != null) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

void main() {
  late _FakeTileCache cache;
  late OfflineMapRepository repository;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    cache = _FakeTileCache();
    repository = OfflineMapRepository();
    container = ProviderContainer(
      overrides: [tileCacheServiceProvider.overrideWithValue(cache)],
    );
  });

  tearDown(() async {
    container.dispose();
    // Not awaited: close() on a controller nobody listened to completes only
    // once a subscriber drains it, so awaiting it here hangs the test.
    if (!cache.progress.isClosed) unawaited(cache.progress.close());
    await tearDownTestDatabase();
  });

  // Lazy: TileLayer creates an HTTP client, and the body of main() runs while
  // the file is declared. By then another file in the isolate may have set up
  // the test binding, whose HTTP layer only works inside a test.
  late final tileLayer = TileLayer(
    urlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
  );

  Future<void> downloadOneRegion({int tiles = 40}) async {
    final notifier = container.read(downloadProgressProvider.notifier);
    final done = notifier.downloadRegion(
      name: 'Cozumel',
      minLat: 20,
      maxLat: 21,
      minLng: -87,
      maxLng: -86,
      minZoom: 8,
      maxZoom: 12,
      tileLayerOptions: tileLayer,
    );
    await Future<void>.delayed(Duration.zero);
    cache.progress.add(
      TileDownloadProgress(
        downloadedTiles: tiles,
        totalTiles: tiles,
        failedTiles: 0,
        tilesPerSecond: 10,
        isComplete: true,
      ),
    );
    await cache.progress.close();
    await done;
  }

  group('download', () {
    test('records the measured size, not a per-tile constant', () async {
      cache.measuredBytes = 3 * 1024 * 1024;

      await downloadOneRegion(tiles: 40);

      final regions = await repository.getAllRegions();
      expect(regions, hasLength(1));
      // The old code stored tiles * 20 KiB, which for 40 tiles would be
      // 800 KiB and would be wrong for essentially every real region.
      expect(regions.single.sizeBytes, 3 * 1024 * 1024);
      expect(regions.single.tileCount, 40);
    });

    test('downloads into a store named for the region it creates', () async {
      await downloadOneRegion();

      final regions = await repository.getAllRegions();
      expect(cache.calls, contains('download:${regions.single.id}'));
      expect(
        cache.calls,
        contains('finish:${regions.single.id}'),
        reason: 'the store is only unprotected once its row exists',
      );
    });

    test('a cancelled download leaves neither tiles nor a region', () async {
      final notifier = container.read(downloadProgressProvider.notifier);
      final done = notifier.downloadRegion(
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileLayerOptions: tileLayer,
      );
      await Future<void>.delayed(Duration.zero);
      cache.progress.add(
        const TileDownloadProgress(
          downloadedTiles: 5,
          totalTiles: 100,
          failedTiles: 0,
          tilesPerSecond: 5,
          isComplete: false,
        ),
      );
      await notifier.cancelDownload();
      await done;

      expect(await repository.getAllRegions(), isEmpty);
      expect(
        cache.calls.where((c) => c.startsWith('discard:')),
        hasLength(1),
        reason: 'the partial store must go, or its tiles are unreachable',
      );
      expect(cache.calls.where((c) => c.startsWith('measure:')), isEmpty);
    });

    test('cancelling one download does not cancel the next', () async {
      // The cancellation is keyed to the region it was aimed at. If it were a
      // bare flag, or the id outlived its download, the next download would
      // discard its own tiles and record nothing.
      final notifier = container.read(downloadProgressProvider.notifier);
      final first = notifier.downloadRegion(
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileLayerOptions: tileLayer,
      );
      await Future<void>.delayed(Duration.zero);
      await notifier.cancelDownload();
      await first;

      expect(await repository.getAllRegions(), isEmpty);

      cache.measuredBytes = 5 * 1024 * 1024;
      await downloadOneRegion(tiles: 12);

      final regions = await repository.getAllRegions();
      expect(regions, hasLength(1));
      expect(regions.single.sizeBytes, 5 * 1024 * 1024);
      expect(
        cache.calls.where((c) => c.startsWith('discard:')),
        hasLength(1),
        reason: 'only the cancelled download discards its store',
      );
    });

    test(
      'cancelling during setup stops the download then, not at the end',
      () async {
        // The progress card is up while the store is still being created, so
        // cancel is reachable before there is any download instance to cancel.
        // Left unhandled, the whole region downloads and is then discarded.
        cache.setupGate = Completer<void>();

        final notifier = container.read(downloadProgressProvider.notifier);
        final done = notifier.downloadRegion(
          name: 'Cozumel',
          minLat: 20,
          maxLat: 21,
          minLng: -87,
          maxLng: -86,
          minZoom: 8,
          maxZoom: 12,
          tileLayerOptions: tileLayer,
        );
        await Future<void>.delayed(Duration.zero);

        // Nothing has started, so this reaches the service as a no-op and the
        // progress stream stays open, exactly as it would in the app.
        await notifier.cancelDownload();
        cache.setupGate!.complete();
        await Future<void>.delayed(Duration.zero);

        // Asserted while the stream is still open, which is the only moment
        // the two behaviours differ: without the check the loop is subscribed
        // here and the region downloads in full before being thrown away.
        expect(
          cache.progress.hasListener,
          isFalse,
          reason: 'the cancelled download is abandoned, not drained to the end',
        );

        unawaited(cache.progress.close());
        await done;

        expect(await repository.getAllRegions(), isEmpty);
        expect(
          cache.calls.where((c) => c.startsWith('discard:')),
          hasLength(1),
        );
        expect(
          cache.calls.where((c) => c.startsWith('measure:')),
          isEmpty,
          reason: 'nothing was kept, so nothing should have been measured',
        );
      },
    );

    test('a download that supersedes another discards it', () async {
      // Starting a second region cancels the first inside the service. Without
      // the first being marked cancelled, its loop would end and it would
      // record a region for whatever few tiles it had, which is the phantom
      // region this branch removed from the cancel path.
      final notifier = container.read(downloadProgressProvider.notifier);
      final first = notifier.downloadRegion(
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileLayerOptions: tileLayer,
      );
      await Future<void>.delayed(Duration.zero);
      cache.progress.add(
        const TileDownloadProgress(
          downloadedTiles: 3,
          totalTiles: 500,
          failedTiles: 0,
          tilesPerSecond: 3,
          isComplete: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      cache.measuredBytes = 2 * 1024 * 1024;
      await downloadOneRegion(tiles: 25);
      await first;

      final regions = await repository.getAllRegions();
      expect(
        regions,
        hasLength(1),
        reason: 'only the download that finished is a region',
      );
      expect(regions.single.tileCount, 25);
      expect(cache.calls.where((c) => c.startsWith('discard:')), hasLength(1));
    });

    test(
      'cancel still works on the download that superseded another',
      () async {
        // The superseded download finishes after the new one has started. If it
        // clears the active slot on its way out, the new download becomes
        // uncancellable: cancel marks nothing, the transfer stops anyway, and a
        // region is recorded for whatever had arrived.
        final notifier = container.read(downloadProgressProvider.notifier);
        final first = notifier.downloadRegion(
          name: 'Cozumel',
          minLat: 20,
          maxLat: 21,
          minLng: -87,
          maxLng: -86,
          minZoom: 8,
          maxZoom: 12,
          tileLayerOptions: tileLayer,
        );
        await Future<void>.delayed(Duration.zero);

        final second = notifier.downloadRegion(
          name: 'Bonaire',
          minLat: 12,
          maxLat: 13,
          minLng: -69,
          maxLng: -68,
          minZoom: 8,
          maxZoom: 12,
          tileLayerOptions: tileLayer,
        );
        await first;
        await Future<void>.delayed(Duration.zero);

        await notifier.cancelDownload();
        await second;

        expect(
          await repository.getAllRegions(),
          isEmpty,
          reason: 'neither download was kept, so neither is a region',
        );
        expect(
          cache.calls.where((c) => c.startsWith('discard:')),
          hasLength(2),
        );
      },
    );

    test('a failed download leaves no store behind', () async {
      // The store is created before the first tile arrives, so a download that
      // throws anywhere after that would strand it holding tiles no region
      // could reach.
      cache.downloadError = StateError('tile server unreachable');

      final notifier = container.read(downloadProgressProvider.notifier);
      await notifier.downloadRegion(
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileLayerOptions: tileLayer,
      );

      expect(await repository.getAllRegions(), isEmpty);
      expect(cache.calls.where((c) => c.startsWith('discard:')), hasLength(1));
      expect(
        container.read(downloadProgressProvider).error,
        contains('tile server unreachable'),
        reason:
            'the diver must see why the download failed, not why the '
            'cleanup after it did',
      );
    });
  });

  group('clear all', () {
    test('drops every region row and all of their tiles', () async {
      for (final id in ['a', 'b']) {
        await repository.createRegion(
          id: id,
          name: 'Region $id',
          minLat: 20,
          maxLat: 21,
          minLng: -87,
          maxLng: -86,
          minZoom: 8,
          maxZoom: 12,
          tileCount: 10,
          sizeBytes: 1024,
        );
      }

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .clearAllCache();

      expect(cache.calls, contains('clearCache'));
      expect(await repository.getAllRegions(), isEmpty);
    });
  });

  group('clear all failure', () {
    test('drops the rows whose tiles did go, and still reports', () async {
      // The shared-store reset failing says nothing about a region whose own
      // tiles were deleted successfully. Keeping its row would describe bytes
      // that are not there; the failure is reported all the same.
      await repository.createRegion(
        id: 'a',
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileCount: 10,
        sizeBytes: 1024,
      );
      cache.clearCacheError = StateError('the browse store is locked');

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .clearAllCache();

      expect(await repository.getAllRegions(), isEmpty);
      expect(
        container.read(cachedRegionsNotifierProvider).hasError,
        isTrue,
        reason: 'a clear that did not clear everything must say so',
      );
    });
  });

  group('clear during a download', () {
    test('discards the running download instead of orphaning it', () async {
      // The running download owns a store with no row yet, so nothing in the
      // clear loop would see it, and the reset would delete the store out from
      // under it. Left unhandled, that download then finishes and records a
      // region for tiles the clear had already removed.
      final downloads = container.read(downloadProgressProvider.notifier);
      final running = downloads.downloadRegion(
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileLayerOptions: tileLayer,
      );
      await Future<void>.delayed(Duration.zero);

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .clearAllCache();
      await running;

      expect(await repository.getAllRegions(), isEmpty);
      expect(
        cache.calls.where((c) => c.startsWith('discard:')),
        hasLength(1),
        reason: 'the interrupted download gives up its own store',
      );
      expect(cache.calls.where((c) => c.startsWith('measure:')), isEmpty);
    });
  });

  group('partial clear', () {
    test('keeps only the regions whose tiles are still there', () async {
      // A row whose tiles are gone is worse than no row: the page would offer
      // it as a region, call its size unmeasurable, and warn that deleting it
      // frees nothing, when there is nothing left to free.
      for (final id in ['gone', 'stuck']) {
        await repository.createRegion(
          id: id,
          name: 'Region $id',
          minLat: 20,
          maxLat: 21,
          minLng: -87,
          maxLng: -86,
          minZoom: 8,
          maxZoom: 12,
          tileCount: 10,
          sizeBytes: 1024,
        );
      }
      cache.undeletableRegionIds.add('stuck');

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .clearAllCache();

      final left = await repository.getAllRegions();
      expect(left.map((r) => r.id), ['stuck']);
      expect(
        container.read(cachedRegionsNotifierProvider).hasError,
        isTrue,
        reason: 'a clear that did not clear everything must say so',
      );
    });
  });

  group('delete', () {
    Future<String> seedRegion({String id = 'region-1'}) async {
      await repository.createRegion(
        id: id,
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileCount: 100,
        sizeBytes: 2048,
      );
      return id;
    }

    test('removes the tiles before the row', () async {
      final id = await seedRegion();

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .deleteRegion(id);

      expect(cache.calls, contains('deleteTiles:$id'));
      expect(await repository.getRegionById(id), isNull);
    });

    test('keeps the row when the tiles could not be removed', () async {
      // Losing the row while the bytes survive is the exact failure this
      // issue is about: the tiles become unreachable and invisible.
      final id = await seedRegion();
      cache.deleteTilesError = StateError('store locked');

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .deleteRegion(id);

      expect(await repository.getRegionById(id), isNotNull);
    });
  });

  group('orphan stores', () {
    test('the sweep is told exactly which regions still exist', () async {
      await repository.createRegion(
        id: 'kept',
        name: 'Cozumel',
        minLat: 20,
        maxLat: 21,
        minLng: -87,
        maxLng: -86,
        minZoom: 8,
        maxZoom: 12,
        tileCount: 10,
        sizeBytes: 1024,
      );

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .pruneOrphanStores();

      expect(cache.calls, contains('prune:kept'));
    });

    test('the sweep reports what it reclaimed', () async {
      // The caller needs this: storage totals already on screen were measured
      // before the sweep deleted anything.
      cache.prunedStores = 3;

      final reclaimed = await container
          .read(cachedRegionsNotifierProvider.notifier)
          .pruneOrphanStores();

      expect(reclaimed, 3);
    });

    test('a region recorded while the sweep runs is not swept', () async {
      // The rows are read after the store list, never before it. A download
      // that finishes inside that window has already written its row and
      // dropped its in-flight mark, so a snapshot taken up front would show
      // neither, and the sweep would delete the store of a region that exists.
      cache.beforeReadingRegions = () async {
        await repository.createRegion(
          id: 'just-finished',
          name: 'Bonaire',
          minLat: 12,
          maxLat: 13,
          minLng: -69,
          maxLng: -68,
          minZoom: 8,
          maxZoom: 12,
          tileCount: 40,
          sizeBytes: 4096,
        );
      };

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .pruneOrphanStores();

      expect(cache.calls, contains('prune:just-finished'));
    });
  });

  group('superseded download', () {
    Future<void> start(DownloadProgressNotifier notifier, String name) =>
        notifier.downloadRegion(
          name: name,
          minLat: 20,
          maxLat: 21,
          minLng: -87,
          maxLng: -86,
          minZoom: 8,
          maxZoom: 12,
          tileLayerOptions: tileLayer,
        );

    test('leaves the download that replaced it on screen', () async {
      // The progress card is gated on isDownloading. A superseded download
      // finishes after the one that replaced it started, and blanking the
      // shared state on its way out left the diver watching a download with
      // no progress bar and no way to cancel it until it ended.
      final notifier = container.read(downloadProgressProvider.notifier);
      final first = start(notifier, 'Cozumel');
      await Future<void>.delayed(Duration.zero);
      final second = start(notifier, 'Bonaire');
      await first;
      await Future<void>.delayed(Duration.zero);

      final state = container.read(downloadProgressProvider);
      expect(state.isDownloading, isTrue);
      expect(state.regionName, 'Bonaire');
      expect(state.error, isNull);

      await notifier.cancelDownload();
      await second;
    });

    test('stops writing progress once it has been replaced', () async {
      // Cancelling is not instant: the service cancels the download instance
      // and only then cancels the subscription, so a superseded download can
      // emit a tick or two on the way out. Written to the shared card those
      // numbers land under the new download's name, and the diver reads the
      // abandoned region's tile counts as the progress of the one they just
      // started.
      final notifier = container.read(downloadProgressProvider.notifier);
      final first = start(notifier, 'Cozumel');
      await Future<void>.delayed(Duration.zero);

      cache.cancelGate = Completer<void>();
      final second = start(notifier, 'Bonaire');
      await Future<void>.delayed(Duration.zero);

      // The first download's stream is still open, and it is no longer the one
      // on screen.
      cache.progress.add(
        const TileDownloadProgress(
          downloadedTiles: 999,
          totalTiles: 1000,
          failedTiles: 7,
          tilesPerSecond: 42,
          isComplete: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(downloadProgressProvider);
      expect(state.regionName, 'Bonaire');
      expect(
        state.downloadedTiles,
        0,
        reason: "the abandoned region's tiles are not the new one's progress",
      );
      expect(state.totalTiles, 0);
      expect(state.failedTiles, 0);

      cache.cancelGate!.complete();
      await first;
      await notifier.cancelDownload();
      await second;
    });

    test('a third download does not strand the first as a region', () async {
      // Only one cancelled region used to be remembered, so a third download
      // displaced the first one's mark. The first then fell through to its
      // success path and recorded a region for the handful of tiles it had,
      // which is the phantom region the cancel path exists to prevent.
      final notifier = container.read(downloadProgressProvider.notifier);
      final first = start(notifier, 'Cozumel');
      await Future<void>.delayed(Duration.zero);
      // Not awaited between the two: downloadRegion marks the download it
      // supersedes synchronously, before its first await, so back-to-back
      // starts are what displace the first one's mark while it is still in
      // its loop. Letting the first one settle in between hides the bug.
      final second = start(notifier, 'Bonaire');
      final third = start(notifier, 'Roatan');
      await first;
      await second;
      await Future<void>.delayed(Duration.zero);

      cache.progress.add(
        const TileDownloadProgress(
          downloadedTiles: 25,
          totalTiles: 25,
          failedTiles: 0,
          tilesPerSecond: 10,
          isComplete: true,
        ),
      );
      await cache.progress.close();
      await third;

      final regions = await repository.getAllRegions();
      expect(regions.map((r) => r.name), ['Roatan']);
    });
  });

  group('clear all reporting', () {
    Future<void> seed(String id, String name) => repository.createRegion(
      id: id,
      name: name,
      minLat: 20,
      maxLat: 21,
      minLng: -87,
      maxLng: -86,
      minZoom: 8,
      maxZoom: 12,
      tileCount: 10,
      sizeBytes: 1024,
    );

    test('a failed shared-store reset still refreshes the totals', () async {
      // The throw used to jump straight past the reload and both
      // invalidations, so the storage card kept describing bytes that the loop
      // above had already freed. The rows going is exactly why it has to be
      // re-measured, whether or not the reset that followed them worked.
      await seed('a', 'Cozumel');
      cache.clearCacheError = StateError('the browse store is locked');

      final sub = container.listen(cacheStatsProvider, (_, _) {});
      await container.read(cacheStatsProvider.future);
      final measurementsBefore = cache.statsReads;

      await container
          .read(cachedRegionsNotifierProvider.notifier)
          .clearAllCache();
      await container.read(cacheStatsProvider.future);

      expect(
        cache.statsReads,
        greaterThan(measurementsBefore),
        reason: 'the totals on screen were measured before the rows went',
      );
      expect(
        container.read(cachedRegionsNotifierProvider).hasError,
        isTrue,
        reason: 'a clear that did not clear everything still has to say so',
      );
      sub.close();
    });
  });
}
