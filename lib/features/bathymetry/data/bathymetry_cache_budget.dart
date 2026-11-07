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

/// Evicts the least recently read 'ok' grids in `bathymetry_cache` until
/// their stored bytes fit [budgetBytes], and returns how many it deleted.
///
/// [keepKey] is never evicted: it is the grid the caller just wrote, which
/// the scene is about to draw. 'empty' rows hold no grid, cost a few bytes,
/// and save a network round trip each, so they are left alone.
///
/// Reads only the key, size and stamps, never a grid. A legacy row whose
/// size predates the `grid_bytes` column counts as zero; the v20 rung
/// backfills every such row, so none is expected.
Future<int> evictBathymetryCacheOverBudget(
  LocalCacheDatabase db, {
  int budgetBytes = kBathymetryCacheByteBudget,
  String? keepKey,
}) async {
  final t = db.bathymetryCache;
  final rows =
      await (db.selectOnly(t)
            ..addColumns([t.cacheKey, t.gridBytes, t.lastUsedAt, t.fetchedAt])
            ..where(t.status.equals('ok')))
          .map(
            (r) => (
              key: r.read(t.cacheKey)!,
              bytes: r.read(t.gridBytes) ?? 0,
              usedAt: r.read(t.lastUsedAt) ?? r.read(t.fetchedAt)!,
            ),
          )
          .get();

  var total = rows.fold<int>(0, (sum, r) => sum + r.bytes);
  if (total <= budgetBytes) return 0;

  // Oldest first; the key breaks ties so the order is stable.
  final oldestFirst = [...rows]
    ..sort((a, b) {
      final byUse = a.usedAt.compareTo(b.usedAt);
      return byUse != 0 ? byUse : a.key.compareTo(b.key);
    });
  final evict = <String>[];
  for (final row in oldestFirst) {
    if (total <= budgetBytes) break;
    if (row.key == keepKey) continue;
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
