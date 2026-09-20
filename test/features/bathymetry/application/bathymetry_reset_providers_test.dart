import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_reset_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

BathymetryGrid _gridFor(String sourceId) => BathymetryGrid(
  originLat: 47.2,
  originLon: 9.1,
  cellSizeLatDeg: 0.004,
  cellSizeLonDeg: 0.004,
  rows: 2,
  cols: 2,
  depthsMeters: const [1, 2, 3, 4],
  sourceId: sourceId,
  resolutionMeters: 2,
  fetchedAt: DateTime.utc(2026, 1, 1),
);

/// A resolver double whose fetch() always returns a grid tagged [sourceId],
/// and counts calls so a test can tell whether a reload actually re-fetched.
class TaggedSource implements BathymetrySource {
  final String sourceId;
  final void Function()? onFetch;
  int calls = 0;
  TaggedSource(this.sourceId, {this.onFetch});

  @override
  String get id => sourceId;
  @override
  bool get global => true;
  @override
  double get minKnownFraction => 0.60;
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(cellSizeMeters: 100, detail: 'fake');
  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    calls++;
    onFetch?.call();
    return _gridFor(sourceId);
  }
}

void main() {
  const betlis = GeoPoint(47.135503, 9.144546);
  const bonaire = GeoPoint(12.16, -68.29);

  late LocalCacheDatabase db;
  setUp(() => db = LocalCacheDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer buildContainer({
    required BathymetryRepository repo,
    List<GeoPoint> sites = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        bathymetryRepositoryProvider.overrideWithValue(repo),
        swissBathyTileCacheRepositoryProvider.overrideWithValue(
          SwissBathyTileCacheRepository(db),
        ),
        knownDiveSiteLocationsProvider.overrideWith((ref) async => sites),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'swissBathyClearProvider invalidates mapReloadEstimateProvider and '
    'bathymetryGridProvider so both recompute against the now-emptied '
    'cache instead of serving a stale value from before the delete '
    '(regression: found by code review -- neither was invalidated)',
    () async {
      final swiss = TaggedSource('swissbathy3d');
      final repo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [swiss]),
      );
      // Seeds a cached row so both providers below have something non-null
      // to report before the clear.
      await repo.getGrid(betlis);
      expect(swiss.calls, 1);

      final container = buildContainer(repo: repo, sites: const [betlis]);
      final cell = BathymetryRepository.quantize(betlis);
      // Keeps the family instance alive so invalidating the whole family
      // actually has something to mark dirty, matching how a real dive
      // site's 3D view holds it open.
      final gridSub = container.listen(bathymetryGridProvider(cell), (_, _) {});
      addTearDown(gridSub.close);

      final firstEstimate = await container.read(
        mapReloadEstimateProvider.future,
      );
      expect(firstEstimate!.averageBytesPerSite, isNotNull);
      final firstGrid = await container.read(
        bathymetryGridProvider(cell).future,
      );
      expect(firstGrid, isNotNull);
      // The cell was already cached from the seed call above, so this read
      // was a cache hit -- no second fetch yet.
      expect(swiss.calls, 1);

      await container.read(swissBathyClearProvider)();

      final secondEstimate = await container.read(
        mapReloadEstimateProvider.future,
      );
      expect(
        secondEstimate!.averageBytesPerSite,
        isNull,
        reason:
            'the cache is now empty; a stale, un-invalidated provider '
            'would still report the old non-null average',
      );
      final secondGrid = await container.read(
        bathymetryGridProvider(cell).future,
      );
      expect(secondGrid, isNotNull); // re-resolved, not the old stale grid
      expect(
        swiss.calls,
        2,
        reason:
            'a genuine re-fetch must have happened; a stale, '
            'un-invalidated provider would still serve the first grid '
            'without calling the source again',
      );
    },
  );

  test(
    'swissBathyClearProvider removes only swissBATHY3D rows, not others',
    () async {
      final swiss = TaggedSource('swissbathy3d');
      final other = TaggedSource('gmrt');
      final repo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [swiss]),
      );
      final otherRepo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [other]),
      );
      await repo.getGrid(betlis);
      await otherRepo.getGrid(bonaire);

      final container = buildContainer(repo: repo);
      await container.read(swissBathyClearProvider)();

      expect(await repo.hasCachedAnswer(betlis), isFalse);
      expect(await otherRepo.hasCachedAnswer(bonaire), isTrue);
    },
  );

  test(
    'bathymetryOtherSourcesClearProvider removes non-swissBATHY3D rows only',
    () async {
      final swiss = TaggedSource('swissbathy3d');
      final other = TaggedSource('gmrt');
      final repo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [swiss]),
      );
      final otherRepo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [other]),
      );
      await repo.getGrid(betlis);
      await otherRepo.getGrid(bonaire);

      final container = buildContainer(repo: repo);
      await container.read(bathymetryOtherSourcesClearProvider)();

      expect(await repo.hasCachedAnswer(betlis), isTrue);
      expect(await otherRepo.hasCachedAnswer(bonaire), isFalse);
    },
  );

  group('MapReloadNotifier', () {
    test('reports an error rather than a silent success when the local cache '
        'database is not initialized (every clear/fetch step would otherwise '
        'no-op and the run would look complete)', () async {
      final container = ProviderContainer(
        overrides: [
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith(
            (ref) async => const [betlis, bonaire],
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(mapReloadProvider.notifier).start();

      final state = container.read(mapReloadProvider);
      expect(state.isRunning, isFalse);
      expect(state.error, isNotNull);
      expect(state.completed, 0);
    });

    test('refreshes the known-site list instead of reusing the one already '
        'cached for the session, so a dive site added (or pulled in by sync) '
        'after the list was last read is still reloaded (regression: found by '
        'code review -- start() read the memoized value)', () async {
      final source = TaggedSource('gmrt');
      final repo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [source]),
      );
      // Mutated between the priming read and start(), standing in for a
      // dive site that appears while the app is already running.
      final sites = <GeoPoint>[betlis];
      final container = ProviderContainer(
        overrides: [
          bathymetryRepositoryProvider.overrideWithValue(repo),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(
            SwissBathyTileCacheRepository(db),
          ),
          knownDiveSiteLocationsProvider.overrideWith(
            (ref) async => List<GeoPoint>.of(sites),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Primes the provider's cache the way the confirmation dialog's own
      // estimate does, before the diver ever presses Reload.
      expect(await container.read(knownDiveSiteLocationsProvider.future), [
        betlis,
      ]);
      sites.add(bonaire);

      await container.read(mapReloadProvider.notifier).start();

      final state = container.read(mapReloadProvider);
      expect(state.total, 2);
      expect(state.completed, 2);
      expect(source.calls, 2);
    });

    test('clears both caches, then re-fetches every known site', () async {
      final source = TaggedSource('gmrt');
      final repo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [source]),
      );
      // Pre-existing cached rows that the reload must clear before re-fetching.
      await repo.getGrid(betlis);
      await repo.getGrid(bonaire);
      expect(source.calls, 2);

      final container = buildContainer(
        repo: repo,
        sites: const [betlis, bonaire],
      );

      await container.read(mapReloadProvider.notifier).start();

      final state = container.read(mapReloadProvider);
      expect(state.isRunning, isFalse);
      expect(state.cancelled, isFalse);
      expect(state.total, 2);
      expect(state.completed, 2);
      // Cleared and re-fetched: 2 initial + 2 during reload.
      expect(source.calls, 4);
    });

    test('cancel stops scheduling further sites, but the site already in '
        'flight still completes and counts', () async {
      const thirdSite = GeoPoint(0, 0);
      late MapReloadNotifier notifier;
      final source = TaggedSource(
        'gmrt',
        onFetch: () {
          // Fires after the FIRST site's fetch resolves (calls == 1),
          // simulating "cancel pressed while a request is in flight":
          // that site still finishes and counts, but the loop must not
          // start the second or third site afterwards.
          notifier.cancel();
        },
      );
      final repo = BathymetryRepository(
        db: db,
        resolver: BathymetryResolver(sources: [source]),
      );
      final container = buildContainer(
        repo: repo,
        sites: const [betlis, bonaire, thirdSite],
      );
      notifier = container.read(mapReloadProvider.notifier);

      await notifier.start();

      final state = container.read(mapReloadProvider);
      expect(state.cancelled, isTrue);
      expect(state.total, 3);
      expect(state.completed, 1);
      expect(source.calls, 1);
    });
  });

  test('mapReloadEstimateProvider reports the known site count and an '
      'average size once something is cached', () async {
    final source = TaggedSource('gmrt');
    final repo = BathymetryRepository(
      db: db,
      resolver: BathymetryResolver(sources: [source]),
    );
    await repo.getGrid(betlis);

    final container = buildContainer(
      repo: repo,
      sites: const [betlis, bonaire],
    );

    final estimate = await container.read(mapReloadEstimateProvider.future);
    expect(estimate, isNotNull);
    expect(estimate!.siteCount, 2);
    expect(estimate.averageBytesPerSite, isNotNull);
    expect(estimate.formattedEstimatedSize, isNotNull);
  });

  test('mapReloadEstimateProvider omits a size when nothing is cached to '
      'average from', () async {
    final source = TaggedSource('gmrt');
    final repo = BathymetryRepository(
      db: db,
      resolver: BathymetryResolver(sources: [source]),
    );

    final container = buildContainer(repo: repo, sites: const [betlis]);

    final estimate = await container.read(mapReloadEstimateProvider.future);
    expect(estimate, isNotNull);
    expect(estimate!.averageBytesPerSite, isNull);
    expect(estimate.formattedEstimatedSize, isNull);
  });

  test('MapReloadEstimate omits a size when siteCount is 0, even with a '
      'non-null average (regression: found by code review -- multiplying by '
      'a 0 siteCount produced a fabricated "0 B" instead of no estimate)', () {
    const estimate = MapReloadEstimate(siteCount: 0, averageBytesPerSite: 1024);
    expect(estimate.estimatedBytes, isNull);
    expect(estimate.formattedEstimatedSize, isNull);
  });
}
