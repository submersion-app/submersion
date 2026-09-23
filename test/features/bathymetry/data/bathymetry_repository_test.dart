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
  double get minKnownFraction => 0.60;
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(cellSizeMeters: 100, detail: 'fake');
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

/// Records every center it was asked to fetch, tagging each returned grid
/// with the call's index -- so a test can tell which fetch call produced
/// which cached grid.
class CenterRecordingSource implements BathymetrySource {
  final List<GeoPoint> centers = [];
  double? lastSpanMeters;

  @override
  String get id => 'recorder';
  @override
  bool get global => true;
  @override
  double get minKnownFraction => 0.60;
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(cellSizeMeters: 100, detail: 'recorder');
  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    centers.add(c);
    lastSpanMeters = spanMeters;
    return BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 0.004,
      cellSizeLonDeg: 0.004,
      rows: 2,
      cols: 2,
      depthsMeters: const [10, 20, 30, 40],
      sourceId: 'recorder',
      resolutionMeters: centers.length.toDouble(),
      fetchedAt: DateTime.utc(2026, 7, 28),
    );
  }
}

/// A source that ignores [spanMeters] entirely and always returns a wide
/// (101x101, ~11 km) grid centered exactly on the requested coordinate --
/// standing in for etopo_erddap_source.dart's 10 km fetch-box floor, which
/// applies regardless of how narrow an LOD patch actually asked for.
class OversizedGridSource implements BathymetrySource {
  static const double cellSizeDeg = 0.001; // ~111 m/cell at these latitudes
  static const int dim = 101; // spans ~11.1 km, centered on row/col 50

  @override
  String get id => 'oversized';
  @override
  bool get global => true;
  @override
  double get minKnownFraction => 0.60;
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(cellSizeMeters: 450, detail: 'oversized');
  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    return BathymetryGrid(
      originLat: c.latitude - cellSizeDeg * (dim - 1) / 2,
      originLon: c.longitude - cellSizeDeg * (dim - 1) / 2,
      cellSizeLatDeg: cellSizeDeg,
      cellSizeLonDeg: cellSizeDeg,
      rows: dim,
      cols: dim,
      depthsMeters: List<double?>.filled(dim * dim, 10),
      sourceId: 'oversized',
      resolutionMeters: 450,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );
  }
}

void main() {
  const bonaire = GeoPoint(12.16, -68.29);
  // Both inside Walensee's bounding box (see swiss_lake_levels.dart), both
  // floor onto the SAME 0.02 degree cell (47.12, 9.14) despite being real,
  // distinct dive sites in different 1 km swissBATHY3D tiles -- exactly the
  // Bug 10 scenario (Betlis vs. Murg West rendering the same mesh).
  const betlis = GeoPoint(47.135503, 9.144546);
  const murgWest = GeoPoint(47.138, 9.148);

  late LocalCacheDatabase db;
  setUp(() => db = LocalCacheDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  BathymetryRepository repo(BathymetrySource source) => BathymetryRepository(
    db: db,
    resolver: BathymetryResolver(sources: [source]),
  );

  test('quantize floors onto 0.02 degree cells (negative coords too)', () {
    final q = BathymetryRepository.quantize(bonaire);
    expect(q.lat, closeTo(12.16, 1e-9));
    expect(q.lon, closeTo(-68.30, 1e-9)); // -68.29 floors DOWN to -68.30
    // The key carries the request span and the selection generation, so a
    // change to either refetches instead of serving the old cached answer
    // forever.
    expect(BathymetryRepository.keyFor(bonaire), '12.16,-68.30@8000v5');
    // Nearby coordinates share the key.
    expect(
      BathymetryRepository.keyFor(const GeoPoint(12.171, -68.281)),
      '12.16,-68.30@8000v5',
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

  group('swissBATHY3D lakes bypass the 0.02 degree cell (Bug 10)', () {
    test('quantumDegFor/quantize/keyFor use the raw coordinate inside a lake, '
        'not a floored cell', () {
      expect(BathymetryRepository.quantumDegFor(betlis), 0);
      final q = BathymetryRepository.quantize(betlis);
      expect(q.lat, betlis.latitude);
      expect(q.lon, betlis.longitude);

      // Two distinct real sites this close together now get distinct
      // keys...
      expect(
        BathymetryRepository.keyFor(betlis),
        isNot(BathymetryRepository.keyFor(murgWest)),
      );

      // ...even though the OLD, pauschal 0.02 rule would have floored
      // both onto the exact same cell (confirming this is a genuine
      // same-cell collision, not a fabricated test scenario).
      double floor002(double v) => (v / 0.02).floorToDouble() * 0.02;
      expect(
        floor002(betlis.latitude),
        closeTo(floor002(murgWest.latitude), 1e-9),
      );

      // The resolved lake's OWN mean level rides along in the key (Copilot
      // review): a FUTURE correction to Walensee's documented level in
      // swiss_lake_levels.dart automatically changes this key too, without
      // needing a manual selectionGeneration bump for that correction.
      expect(BathymetryRepository.keyFor(betlis), endsWith('@419.07'));
      expect(
        floor002(betlis.longitude),
        closeTo(floor002(murgWest.longitude), 1e-9),
      );
    });

    test(
      'two real sites in the same 0.02 cell but different swissBATHY3D '
      'tiles fetch and cache independently, each at its own coordinate',
      () async {
        final source = CenterRecordingSource();
        final r = repo(source);

        final gridA = await r.getGrid(betlis);
        final gridB = await r.getGrid(murgWest);

        expect(source.centers, [betlis, murgWest]);
        expect(gridA!.resolutionMeters, isNot(gridB!.resolutionMeters));
        final rows = await db.select(db.bathymetryCache).get();
        expect(rows, hasLength(2)); // two rows, not one shared row
      },
    );

    test(
      'non-swiss coordinates in the same 0.02 cell still share one cached '
      'fetch (regression guard: the other three sources are unaffected)',
      () async {
        final source = CenterRecordingSource();
        final r = repo(source);

        final first = await r.getGrid(bonaire);
        final second = await r.getGrid(const GeoPoint(12.171, -68.281));

        expect(first, isNotNull);
        expect(second, isNotNull);
        expect(source.centers, hasLength(1)); // still coalesced, as before
        final rows = await db.select(db.bathymetryCache).get();
        expect(rows, hasLength(1));
      },
    );
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

  group('getGridForSpan (additional LOD patch)', () {
    test('keyFor with an explicit span differs from the base-square key', () {
      final baseKey = BathymetryRepository.keyFor(bonaire);
      final patchKey = BathymetryRepository.keyFor(bonaire, spanMeters: 500);
      expect(patchKey, isNot(baseKey));
      expect(patchKey, endsWith('@500v5'));
      // Omitting spanMeters must reproduce the exact base-square key, so
      // every already-cached base row keeps matching untouched.
      expect(
        BathymetryRepository.keyFor(
          bonaire,
          spanMeters: BathymetryResolver.defaultSpanMeters,
        ),
        baseKey,
      );
    });

    test('fetches and caches independently of the base-square grid', () async {
      final source = CenterRecordingSource();
      final r = repo(source);

      final base = await r.getGrid(bonaire);
      final patch = await r.getGridForSpan(bonaire, 500);

      expect(base, isNotNull);
      expect(patch, isNotNull);
      // Two distinct fetches (recorder tags resolutionMeters by call index).
      expect(base!.resolutionMeters, isNot(patch!.resolutionMeters));
      final rows = await db.select(db.bathymetryCache).get();
      expect(rows, hasLength(2));
    });

    test('a second call for the same span reuses the cached row', () async {
      final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
      final r = repo(source);
      final first = await r.getGridForSpan(bonaire, 2000);
      final second = await r.getGridForSpan(bonaire, 2000);
      expect(first, isNotNull);
      expect(second!.depthsMeters, first!.depthsMeters);
      expect(source.calls, 1);
    });

    test('passes the requested span through to the resolver/source', () async {
      final source = CenterRecordingSource();
      final r = repo(source);
      await r.getGridForSpan(bonaire, 500);
      expect(source.lastSpanMeters, 500);
    });

    test('fetches at the EXACT requested coordinate, not a quantized cell '
        'center -- a patch span is often narrower than the quantum cell '
        'offset, so snapping to the cell center could point the patch '
        'nowhere near the actual site', () async {
      final source = CenterRecordingSource();
      final r = repo(source);
      // Deliberately not aligned to any 0.02 degree cell corner.
      const exact = GeoPoint(12.171, -68.281);
      await r.getGridForSpan(exact, 500);
      expect(source.centers, [exact]);
    });

    test('the base-square fetch (defaultSpanMeters, via getGrid) still snaps '
        'to the quantized cell center, unchanged', () async {
      final source = CenterRecordingSource();
      final r = repo(source);
      const c = GeoPoint(12.171, -68.281);
      await r.getGrid(c);
      final q = BathymetryRepository.quantize(c);
      expect(source.centers, [
        GeoPoint(
          q.lat + BathymetryRepository.quantumDeg / 2,
          q.lon + BathymetryRepository.quantumDeg / 2,
        ),
      ]);
    });

    test('two nearby but distinct coordinates in the same 0.02 cell get '
        'distinct patch cache keys and fetch independently, each at its own '
        'exact coordinate', () async {
      final source = CenterRecordingSource();
      final r = repo(source);
      const a = GeoPoint(12.16, -68.29);
      const b = GeoPoint(12.171, -68.281); // same 0.02 cell as a
      expect(
        BathymetryRepository.keyFor(a, spanMeters: 500),
        isNot(BathymetryRepository.keyFor(b, spanMeters: 500)),
      );

      await r.getGridForSpan(a, 500);
      await r.getGridForSpan(b, 500);

      expect(source.centers, [a, b]);
      final rows = await db.select(db.bathymetryCache).get();
      expect(rows, hasLength(2)); // two rows, not one shared row
    });
  });

  group('a source that overshoots the requested span gets cropped back', () {
    test(
      'a fine patch (500 m) fetched from a source that always returns an '
      '~11 km grid (ETOPO\'s 10 km floor) is cropped down to roughly the '
      'requested footprint, not left at the source\'s oversized extent',
      () async {
        final r = repo(OversizedGridSource());
        final grid = await r.getGridForSpan(bonaire, 500);
        expect(grid, isNotNull);
        // The source always hands back a 101x101 (~11 km) grid; cropped to a
        // 500 m span it should be a small fraction of that, not the full
        // extent verbatim.
        expect(grid!.rows, lessThan(20));
        expect(grid.cols, lessThan(20));
        // Still centered close to the requested coordinate -- cropping must
        // not have picked an arbitrary corner of the oversized source grid.
        final midLat =
            grid.originLat + grid.cellSizeLatDeg * (grid.rows - 1) / 2;
        final midLon =
            grid.originLon + grid.cellSizeLonDeg * (grid.cols - 1) / 2;
        expect(midLat, closeTo(bonaire.latitude, 0.002));
        expect(midLon, closeTo(bonaire.longitude, 0.002));
      },
    );

    test('the base-square fetch (8 km) from the same oversized (~11 km) source '
        'is cropped too, since 11 km is still a material overshoot of the '
        'requested 8 km', () async {
      final r = repo(OversizedGridSource());
      final grid = await r.getGrid(bonaire);
      expect(grid, isNotNull);
      expect(grid!.rows, lessThan(OversizedGridSource.dim));
      expect(grid.cols, lessThan(OversizedGridSource.dim));
    });

    test(
      'a source whose grid already matches the requested span is left '
      'untouched (regression guard for every other, well-behaved source)',
      () async {
        final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
        final r = repo(source);
        final grid = await r.getGridForSpan(bonaire, 500);
        expect(grid!.rows, wetGrid().rows);
        expect(grid.cols, wetGrid().cols);
      },
    );
  });

  test('the cache key carries the selection generation', () {
    final key = BathymetryRepository.keyFor(const GeoPoint(12.16, -68.29));
    expect(key, endsWith('@8000v5'));
  });

  test('a row written under the previous generation is not reused', () {
    // An install upgrading from the pre-selection-change build must MISS
    // its old rows, or every already-visited site keeps serving the grid
    // the old resolver chose. Cached rows never expire.
    const p = GeoPoint(12.16, -68.29);
    final q = BathymetryRepository.quantize(p);
    final legacyKey =
        '${q.lat.toStringAsFixed(2)},${q.lon.toStringAsFixed(2)}@8000';
    expect(BathymetryRepository.keyFor(p), isNot(legacyKey));
  });

  group('BathymetryRepository.averageCachedGridBytes', () {
    test('returns null when there are no ok rows to average from', () async {
      final r = repo(ScriptedSource(() => const BathymetryResolution.empty()));
      await r.getGrid(bonaire); // caches an 'empty' row, not 'ok'
      expect(await r.averageCachedGridBytes(), isNull);
    });

    test('averages the JSON byte size of every ok row', () async {
      final r = repo(ScriptedSource(() => BathymetryResolution.ok(wetGrid())));
      await r.getGrid(bonaire);
      final avg = await r.averageCachedGridBytes();
      expect(avg, isNotNull);
      expect(avg, greaterThan(0));
    });
  });

  group('BathymetryRepository.clearBySource', () {
    test('deletes only rows attributed to the given source', () async {
      final swissSite = repo(
        ScriptedSource(() {
          final g = wetGrid();
          return BathymetryResolution.ok(
            BathymetryGrid(
              originLat: g.originLat,
              originLon: g.originLon,
              cellSizeLatDeg: g.cellSizeLatDeg,
              cellSizeLonDeg: g.cellSizeLonDeg,
              rows: g.rows,
              cols: g.cols,
              depthsMeters: g.depthsMeters,
              sourceId: 'swissbathy3d',
              resolutionMeters: g.resolutionMeters,
              fetchedAt: g.fetchedAt,
            ),
          );
        }),
      );
      final otherSite = repo(
        ScriptedSource(() => BathymetryResolution.ok(wetGrid())),
      );

      await swissSite.getGrid(betlis);
      await otherSite.getGrid(bonaire);

      await swissSite.clearBySource('swissbathy3d');

      expect(await swissSite.hasCachedAnswer(betlis), isFalse);
      expect(await otherSite.hasCachedAnswer(bonaire), isTrue);
    });
  });

  group('BathymetryRepository.clearAllExceptSource', () {
    test('deletes rows from other sources and rows with no sourceId at all, '
        'leaving only rows attributed to the given source', () async {
      final swissRepo = repo(
        ScriptedSource(() {
          final g = wetGrid();
          return BathymetryResolution.ok(
            BathymetryGrid(
              originLat: g.originLat,
              originLon: g.originLon,
              cellSizeLatDeg: g.cellSizeLatDeg,
              cellSizeLonDeg: g.cellSizeLonDeg,
              rows: g.rows,
              cols: g.cols,
              depthsMeters: g.depthsMeters,
              sourceId: 'swissbathy3d',
              resolutionMeters: g.resolutionMeters,
              fetchedAt: g.fetchedAt,
            ),
          );
        }),
      );
      final otherRepo = repo(
        ScriptedSource(() => BathymetryResolution.ok(wetGrid())),
      );
      // A definitive "no water here" negative: a global source found dry
      // land, so the row is cached with no sourceId at all (see _load()'s
      // 'empty' branch).
      final dryRepo = repo(
        ScriptedSource(() => const BathymetryResolution.empty()),
      );

      await swissRepo.getGrid(betlis);
      await otherRepo.getGrid(bonaire);
      await dryRepo.getGrid(murgWest);

      await swissRepo.clearAllExceptSource('swissbathy3d');

      expect(await swissRepo.hasCachedAnswer(betlis), isTrue);
      expect(await otherRepo.hasCachedAnswer(bonaire), isFalse);
      expect(await dryRepo.hasCachedAnswer(murgWest), isFalse);
    });
  });
}
