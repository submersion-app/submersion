import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';

/// The most grid bytes `bathymetry_cache` keeps (issue #4258). About 1,500
/// base squares, or 40 sites with every zoom stage cached, in the compact
/// form `bathymetry_grid_codec.dart` stores.
const int kBathymetryCacheByteBudget = 128 * 1024 * 1024;

/// How stale a row's last-read stamp may grow before a read refreshes it.
/// Eviction only needs a coarse order, and this keeps a scene that reloads
/// its grids from writing on every load.
const Duration kBathymetryCacheTouchInterval = Duration(hours: 1);

/// Rows deleted per statement, under SQLite's oldest variable limit of 999.
const int _deleteChunk = 500;

/// The grid bytes a `bathymetry_cache` row stores: its recorded
/// `grid_bytes`, or, for a row cached as JSON before v20 and not read since,
/// its JSON's size in UTF-8 bytes. `octet_length` reads that size from the
/// record header, so sizing a legacy row never loads its grid, and the v20
/// upgrade did not have to rewrite every legacy row to record it.
Expression<int> bathymetryStoredBytes($BathymetryCacheTable t) => coalesce([
  t.gridBytes,
  FunctionCallExpression('octet_length', [t.gridJson]),
]);

/// Evicts the least recently read 'ok' grids in `bathymetry_cache` until
/// their stored bytes fit [budgetBytes], and returns how many it deleted.
///
/// [keepKeys] are never evicted: the grids the caller has just written or
/// is still loading, which a scene is about to draw. A load running for
/// another key may have written a row this pass would otherwise evict, so
/// the caller passes every key in flight, not only its own. 'empty' rows
/// hold no grid, cost a few bytes, and save a network round trip each, so
/// they are left alone.
///
/// Rows last used at or after [keepUsedSince] (epoch millis) are kept too.
/// The weekly sweep runs without knowing which loads are in flight, and a
/// grid a load has just written is stamped now, so this keeps the sweep from
/// evicting it whatever order the stamps fall in.
///
/// Reads only the key, size and stamps through `bathymetry_cache_budget_idx`
/// (see [bathymetryStoredBytes]), so never a grid page.
Future<int> evictBathymetryCacheOverBudget(
  LocalCacheDatabase db, {
  int budgetBytes = kBathymetryCacheByteBudget,
  Set<String> keepKeys = const {},
  int? keepUsedSince,
}) async {
  final t = db.bathymetryCache;
  final size = bathymetryStoredBytes(t);
  // The common case, well under budget, answered by one scalar.
  final stored = size.sum();
  final sum =
      await (db.selectOnly(t)
            ..addColumns([stored])
            ..where(t.status.equals('ok')))
          .map((r) => r.read(stored) ?? 0)
          .getSingle();
  if (sum <= budgetBytes) return 0;

  final rows =
      await (db.selectOnly(t)
            ..addColumns([t.cacheKey, size, t.lastUsedAt, t.fetchedAt])
            ..where(t.status.equals('ok')))
          .map(
            (r) => (
              key: r.read(t.cacheKey)!,
              bytes: r.read(size) ?? 0,
              usedAt: r.read(t.lastUsedAt) ?? r.read(t.fetchedAt)!,
            ),
          )
          .get();

  var total = rows.fold<int>(0, (sum, r) => sum + r.bytes);

  // Oldest first; the key breaks ties so the order is stable.
  final oldestFirst = [...rows]
    ..sort((a, b) {
      final byUse = a.usedAt.compareTo(b.usedAt);
      return byUse != 0 ? byUse : a.key.compareTo(b.key);
    });
  final evict = <String>[];
  for (final row in oldestFirst) {
    if (total <= budgetBytes) break;
    if (keepKeys.contains(row.key)) continue;
    if (keepUsedSince != null && row.usedAt >= keepUsedSince) continue;
    evict.add(row.key);
    total -= row.bytes;
  }

  var deleted = 0;
  for (var i = 0; i < evict.length; i += _deleteChunk) {
    final chunk = evict.sublist(
      i,
      i + _deleteChunk > evict.length ? evict.length : i + _deleteChunk,
    );
    deleted += await (db.delete(
      t,
    )..where((row) => row.cacheKey.isIn(chunk))).go();
  }
  return deleted;
}
