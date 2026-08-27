import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  tearDown(() => LocalCacheDatabaseService.instance.resetForTesting());

  test('repository provider is null when the cache DB is uninitialized', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(bathymetryRepositoryProvider), isNull);
  });

  test('repository provider builds once the cache DB exists', () {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(bathymetryRepositoryProvider),
      isA<BathymetryRepository>(),
    );
  });

  test(
    'grid provider yields null (not an error) without a repository',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final grid = await container.read(
        bathymetryGridProvider(
          BathymetryRepository.quantize(const GeoPoint(12.16, -68.29)),
        ).future,
      );
      expect(grid, isNull);
    },
  );

  group('transient nulls are not memoized for the session', () {
    BathymetryGrid wetGrid() => BathymetryGrid(
      originLat: 12.14,
      originLon: -68.31,
      cellSizeLatDeg: 0.004,
      cellSizeLonDeg: 0.004,
      rows: 2,
      cols: 2,
      depthsMeters: const [10, 20, 30, 40],
      sourceId: 'gmrt',
      resolutionMeters: 61,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );

    setUp(() => bathymetryTransientRetryBackoff = Duration.zero);
    tearDown(
      () => bathymetryTransientRetryBackoff = const Duration(seconds: 30),
    );

    test('a failed fetch retries on the next read after the backoff', () async {
      final db = LocalCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      LocalCacheDatabaseService.instance.setTestDatabase(db);
      // First fetch fails transiently, the next succeeds.
      var calls = 0;
      final source = FlakySource(() {
        calls++;
        if (calls == 1) throw const BathymetryFetchException('offline');
        return wetGrid();
      });
      final container = ProviderContainer(
        overrides: [
          bathymetryRepositoryProvider.overrideWith(
            (ref) => BathymetryRepository(
              db: db,
              resolver: BathymetryResolver(sources: [source]),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final cell = BathymetryRepository.quantize(const GeoPoint(12.16, -68.29));

      expect(await container.read(bathymetryGridProvider(cell).future), isNull);
      // The zero-backoff invalidation lands on the event loop; let it run.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final retried = await container.read(bathymetryGridProvider(cell).future);
      expect(retried, isNotNull);
      expect(calls, 2);
    });

    test('a definitive empty stays memoized (no refetch churn)', () async {
      final db = LocalCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      LocalCacheDatabaseService.instance.setTestDatabase(db);
      var calls = 0;
      final dry = List<double?>.filled(10, -1.0);
      final source = FlakySource(() {
        calls++;
        return BathymetryGrid(
          originLat: 0,
          originLon: 0,
          cellSizeLatDeg: 0.004,
          cellSizeLonDeg: 0.004,
          rows: 1,
          cols: 10,
          depthsMeters: dry,
          sourceId: 'gmrt',
          resolutionMeters: 61,
          fetchedAt: DateTime.utc(2026, 7, 28),
        );
      });
      final container = ProviderContainer(
        overrides: [
          bathymetryRepositoryProvider.overrideWith(
            (ref) => BathymetryRepository(
              db: db,
              resolver: BathymetryResolver(sources: [source]),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final cell = BathymetryRepository.quantize(const GeoPoint(38.5, -98.0));

      expect(await container.read(bathymetryGridProvider(cell).future), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await container.read(bathymetryGridProvider(cell).future), isNull);
      expect(calls, 1); // definitive answer cached, not re-fetched
    });
  });
}

class FlakySource implements BathymetrySource {
  final BathymetryGrid Function() script;
  FlakySource(this.script);

  @override
  String get id => 'flaky';
  @override
  bool get global => true;
  @override
  bool covers(GeoPoint center) => true;
  @override
  Future<BathymetryGrid> fetch(
    GeoPoint c, {
    required double spanMeters,
  }) async => script();
}
