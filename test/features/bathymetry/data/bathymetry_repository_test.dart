import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

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

/// A resolver double: scripted resolutions, counts calls.
class ScriptedSource implements BathymetrySource {
  final BathymetryResolution Function() script;
  int calls = 0;
  ScriptedSource(this.script);

  @override
  String get id => 'scripted';
  @override
  bool get global => true;
  @override
  bool covers(GeoPoint center) => true;
  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    calls++;
    final r = script();
    final g = r.grid;
    if (g != null) return g;
    if (r.definitive) {
      // Definitive dry: return an all-land grid.
      return BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 0.004,
        cellSizeLonDeg: 0.004,
        rows: 1,
        cols: 4,
        depthsMeters: const [-1, -2, -3, -4],
        sourceId: 'scripted',
        resolutionMeters: 61,
        fetchedAt: DateTime.utc(2026, 7, 28),
      );
    }
    throw const BathymetryFetchException('down');
  }
}

void main() {
  const bonaire = GeoPoint(12.16, -68.29);

  late LocalCacheDatabase db;
  setUp(() => db = LocalCacheDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  BathymetryRepository repo(ScriptedSource source) => BathymetryRepository(
    db: db,
    resolver: BathymetryResolver(sources: [source]),
  );

  test('quantize floors onto 0.02 degree cells (negative coords too)', () {
    final q = BathymetryRepository.quantize(bonaire);
    expect(q.lat, closeTo(12.16, 1e-9));
    expect(q.lon, closeTo(-68.30, 1e-9)); // -68.29 floors DOWN to -68.30
    // The key carries the request span so a span change refetches instead
    // of serving a smaller cached area forever.
    expect(BathymetryRepository.keyFor(bonaire), '12.16,-68.30@8000');
    // Nearby coordinates share the key.
    expect(
      BathymetryRepository.keyFor(const GeoPoint(12.171, -68.281)),
      '12.16,-68.30@8000',
    );
  });

  test('ok result is cached: second call does not re-resolve', () async {
    final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
    final r = repo(source);
    final first = await r.getGrid(bonaire);
    expect(first!.sourceId, 'gmrt');
    final second = await r.getGrid(bonaire);
    expect(second!.depthsMeters, first.depthsMeters);
    expect(source.calls, 1);
  });

  test('definitive empty is cached as a negative answer', () async {
    final source = ScriptedSource(() => const BathymetryResolution.empty());
    final r = repo(source);
    expect(await r.getGrid(bonaire), isNull);
    expect(await r.getGrid(bonaire), isNull);
    expect(source.calls, 1); // negative answer cached
    final row = await db.select(db.bathymetryCache).getSingle();
    expect(row.status, 'empty');
    expect(row.gridJson, isNull);
  });

  test('transient failure writes NO row and retries next call', () async {
    final source = ScriptedSource(
      () => const BathymetryResolution.transientFailure(),
    );
    final r = repo(source);
    expect(await r.getGrid(bonaire), isNull);
    expect(await db.select(db.bathymetryCache).get(), isEmpty);
    expect(await r.getGrid(bonaire), isNull);
    expect(source.calls, 2); // retried
  });

  test('concurrent calls for one key share a single resolve', () async {
    final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
    final r = repo(source);
    final results = await Future.wait([
      r.getGrid(bonaire),
      r.getGrid(const GeoPoint(12.171, -68.281)), // same quantized cell
    ]);
    expect(results[0], isNotNull);
    expect(results[1], isNotNull);
    expect(source.calls, 1);
  });

  test('a corrupt ok row is dropped and refetched, not wedged', () async {
    final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
    final r = repo(source);
    await db
        .into(db.bathymetryCache)
        .insert(
          BathymetryCacheCompanion.insert(
            cacheKey: BathymetryRepository.keyFor(bonaire),
            centerLat: 12.17,
            centerLon: -68.29,
            status: 'ok',
            gridJson: const Value('{not json'),
            fetchedAt: 1753600000000,
          ),
        );
    final grid = await r.getGrid(bonaire);
    expect(grid, isNotNull); // fell through to a fresh resolve
    expect(source.calls, 1);
    final row = await db.select(db.bathymetryCache).getSingle();
    expect(row.gridJson, isNot('{not json')); // corrupt row replaced
  });

  test('an ok row with NULL gridJson is dropped and refetched too', () async {
    // Same corruption class as unparseable JSON: an 'ok' row without a
    // usable grid must not read as a definitive answer (which would also
    // suppress the provider's transient retry).
    final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
    final r = repo(source);
    await db
        .into(db.bathymetryCache)
        .insert(
          BathymetryCacheCompanion.insert(
            cacheKey: BathymetryRepository.keyFor(bonaire),
            centerLat: 12.17,
            centerLon: -68.29,
            status: 'ok',
            fetchedAt: 1753600000000,
          ),
        );
    final grid = await r.getGrid(bonaire);
    expect(grid, isNotNull);
    expect(source.calls, 1);
    final row = await db.select(db.bathymetryCache).getSingle();
    expect(row.gridJson, isNotNull);
  });

  test('a broken cache table degrades to null, never a throw', () async {
    final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
    final r = repo(source);
    // Force the DB open (beforeOpen self-heal runs), then break the table
    // out from under the repository.
    await db.select(db.bathymetryCache).get();
    await db.customStatement('DROP TABLE bathymetry_cache');
    final grid = await r.getGrid(bonaire);
    expect(grid, isNull); // degraded, not thrown
  });

  test('oversized grids are downsampled before caching', () async {
    final big = BathymetryGrid(
      originLat: 12.14,
      originLon: -68.31,
      cellSizeLatDeg: 0.0001,
      cellSizeLonDeg: 0.0001,
      rows: 200,
      cols: 200,
      depthsMeters: List<double?>.filled(200 * 200, 10),
      sourceId: 'gmrt',
      resolutionMeters: 10,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );
    final source = ScriptedSource(() => BathymetryResolution.ok(big));
    final grid = await repo(source).getGrid(bonaire);
    expect(grid!.rows, lessThanOrEqualTo(120));
    expect(grid.cols, lessThanOrEqualTo(120));
  });
}
