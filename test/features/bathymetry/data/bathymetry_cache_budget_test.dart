import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_cache_budget.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_grid_codec.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

BathymetryGrid _grid({double depth = 10}) => BathymetryGrid(
  originLat: 12.14,
  originLon: -68.31,
  cellSizeLatDeg: 0.004,
  cellSizeLonDeg: 0.004,
  rows: 2,
  cols: 2,
  depthsMeters: [depth, depth + 1, null, depth + 3],
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

/// Answers every fetch with [_grid] and counts the calls.
class _CountingSource implements BathymetrySource {
  int calls = 0;

  @override
  String get id => 'counting';
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
    return _grid();
  }
}

void main() {
  late LocalCacheDatabase db;
  setUp(
    () => db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    ),
  );
  tearDown(() => db.close());

  Future<void> putRow(
    String key, {
    String status = 'ok',
    int? bytes,
    int fetchedAt = 0,
    int? lastUsedAt,
  }) => db
      .into(db.bathymetryCache)
      .insert(
        BathymetryCacheCompanion.insert(
          cacheKey: key,
          centerLat: 0,
          centerLon: 0,
          status: status,
          gridBytes: Value(bytes),
          fetchedAt: fetchedAt,
          lastUsedAt: Value(lastUsedAt),
        ),
      );

  Future<Set<String>> keys() async => {
    for (final row in await db.select(db.bathymetryCache).get()) row.cacheKey,
  };

  group('evictBathymetryCacheOverBudget', () {
    test('deletes nothing while the grids fit', () async {
      await putRow('a', bytes: 40, lastUsedAt: 1);
      await putRow('b', bytes: 60, lastUsedAt: 2);
      expect(await evictBathymetryCacheOverBudget(db, budgetBytes: 100), 0);
      expect(await keys(), {'a', 'b'});
    });

    test('evicts least recently read first, only as far as needed', () async {
      await putRow('old', bytes: 50, lastUsedAt: 1);
      await putRow('middle', bytes: 50, lastUsedAt: 2);
      await putRow('new', bytes: 50, lastUsedAt: 3);
      expect(await evictBathymetryCacheOverBudget(db, budgetBytes: 100), 1);
      expect(await keys(), {'middle', 'new'});
    });

    test('orders a never-read row by when it was fetched', () async {
      await putRow('read-recently', bytes: 50, fetchedAt: 1, lastUsedAt: 30);
      await putRow('fetched-at-20', bytes: 50, fetchedAt: 20);
      await putRow('fetched-at-40', bytes: 50, fetchedAt: 40);
      await evictBathymetryCacheOverBudget(db, budgetBytes: 100);
      expect(await keys(), {'read-recently', 'fetched-at-40'});
    });

    test('never evicts the kept key, even when it is the oldest', () async {
      await putRow('kept', bytes: 80, lastUsedAt: 1);
      await putRow('other', bytes: 80, lastUsedAt: 2);
      await evictBathymetryCacheOverBudget(
        db,
        budgetBytes: 100,
        keepKey: 'kept',
      );
      expect(await keys(), {'kept'});
    });

    test('keeps a kept grid larger than the whole budget', () async {
      await putRow('huge', bytes: 500, lastUsedAt: 1);
      expect(
        await evictBathymetryCacheOverBudget(
          db,
          budgetBytes: 100,
          keepKey: 'huge',
        ),
        0,
      );
      expect(await keys(), {'huge'});
    });

    test('leaves definitive negatives alone', () async {
      await putRow('dry', status: 'empty', lastUsedAt: 0);
      await putRow('a', bytes: 80, lastUsedAt: 1);
      await putRow('b', bytes: 80, lastUsedAt: 2);
      await evictBathymetryCacheOverBudget(db, budgetBytes: 100);
      expect(await keys(), {'dry', 'b'});
    });

    test('deletes past the 999 variable limit in one pass', () async {
      for (var i = 0; i < 1200; i++) {
        await putRow('k$i', bytes: 1, lastUsedAt: i);
      }
      expect(await evictBathymetryCacheOverBudget(db, budgetBytes: 10), 1190);
      expect(await keys(), {for (var i = 1190; i < 1200; i++) 'k$i'});
    });
  });

  group('BathymetryRepository storage', () {
    const bonaire = GeoPoint(12.16, -68.29);
    var clock = DateTime.utc(2026, 11, 7, 9);

    BathymetryRepository repo(
      BathymetrySource source, {
      int byteBudget = kBathymetryCacheByteBudget,
    }) => BathymetryRepository(
      db: db,
      resolver: BathymetryResolver(sources: [source]),
      byteBudget: byteBudget,
      now: () => clock,
    );

    setUp(() => clock = DateTime.utc(2026, 11, 7, 9));

    test('a fetched grid is stored compact, sized and stamped', () async {
      await repo(_CountingSource()).getGrid(bonaire);
      final row = await db.select(db.bathymetryCache).getSingle();
      expect(row.gridJson, isNull);
      expect(BathymetryGridCodec.isEncoded(row.gridBlob!), isTrue);
      expect(row.gridBytes, row.gridBlob!.length);
      expect(row.lastUsedAt, clock.millisecondsSinceEpoch);
      expect(
        BathymetryGridCodec.decode(row.gridBlob!).depthsMeters,
        _grid().depthsMeters,
      );
    });

    test('a legacy JSON row is served, then rewritten compact', () async {
      final source = _CountingSource();
      final r = repo(source);
      final legacy = _grid(depth: 42);
      final json = jsonEncode(legacy.toJson());
      await db
          .into(db.bathymetryCache)
          .insert(
            BathymetryCacheCompanion.insert(
              cacheKey: BathymetryRepository.keyFor(bonaire),
              centerLat: 12.17,
              centerLon: -68.29,
              status: 'ok',
              sourceId: const Value('gmrt'),
              gridJson: Value(json),
              gridBytes: Value(json.length),
              fetchedAt: 1,
            ),
          );

      final first = await r.getGrid(bonaire);
      expect(first!.depthsMeters, legacy.depthsMeters);
      final row = await db.select(db.bathymetryCache).getSingle();
      expect(row.gridJson, isNull);
      expect(row.gridBytes, row.gridBlob!.length);
      expect(row.gridBytes, lessThan(json.length));
      expect(row.lastUsedAt, clock.millisecondsSinceEpoch);
      expect(row.fetchedAt, 1); // still the original download time

      final second = await r.getGrid(bonaire);
      expect(second!.depthsMeters, legacy.depthsMeters);
      expect(source.calls, 0); // served offline both times
    });

    test('a read refreshes the stamp only once the interval passed', () async {
      final r = repo(_CountingSource());
      await r.getGrid(bonaire);
      final written = clock.millisecondsSinceEpoch;

      clock = clock.add(const Duration(minutes: 59));
      await r.getGrid(bonaire);
      var row = await db.select(db.bathymetryCache).getSingle();
      expect(row.lastUsedAt, written);

      clock = clock.add(const Duration(minutes: 1));
      await r.getGrid(bonaire);
      row = await db.select(db.bathymetryCache).getSingle();
      expect(row.lastUsedAt, clock.millisecondsSinceEpoch);
    });

    test('a write past the budget evicts the least recently read grid, '
        'never the one just written', () async {
      await putRow('stale', bytes: 1000, lastUsedAt: 1);
      await putRow('fresh', bytes: 1000, lastUsedAt: 2);
      const budget = 2000 + 50; // room for both old rows, not a third grid
      await repo(_CountingSource(), byteBudget: budget).getGrid(bonaire);
      expect(await keys(), {'fresh', BathymetryRepository.keyFor(bonaire)});
    });

    test('averageCachedGridBytes averages the recorded sizes', () async {
      final r = repo(_CountingSource());
      expect(await r.averageCachedGridBytes(), isNull);
      await putRow('a', bytes: 100, lastUsedAt: 1);
      await putRow('b', bytes: 300, lastUsedAt: 1);
      await putRow('dry', status: 'empty');
      expect(await r.averageCachedGridBytes(), 200);
    });
  });
}
