part of 'swissbathy3d_source.dart';

bool _isStale(DateTime? checkedAt) {
  if (checkedAt == null) return true;
  return DateTime.now().difference(checkedAt) >=
      SwissBathy3dSource.staleCheckInterval;
}

/// Revalidates an expired cached tile with one light STAC item lookup (no
/// asset download) and only re-downloads the zip when the previously-
/// covering asset's version token actually changed, or when that asset
/// cannot be matched among the current candidates at all. Any failure
/// along the way — the metadata lookup itself, the re-download, or
/// reparsing — falls back to serving the still-cached [cached] grid
/// unchanged rather than propagating an error: a stale-but-present tile
/// beats no tile, and per the fair-use requirement this must never turn
/// into an unbounded re-download loop.
///
/// [shared] is the SAME [_SharedFetchState] `fetch()` passed into
/// [SwissBathy3dSource._fetchTile] for this call, not a fresh throwaway one
/// (Copilot review): a span whose tiles have all gone stale together --
/// the common shape for a repeat visit, since every tile of a lake was
/// cached in the same first visit and so expires together too -- used to
/// have each tile's staleness check fire its own independent STAC items
/// lookup for the same lake, reproducing #1764's exact amplification for
/// the revisit path even though the initial-fetch path was fixed.
///
/// [parsedEntries] is likewise `fetch()`'s own single-lake-scoped map --
/// see [SwissBathy3dSource._fetchTile]'s doc for why it travels as its own
/// parameter rather than living on [shared].
///
/// [freshlyResolvedLakes], when given, records [lake]'s name when this
/// check actually re-downloaded and re-parsed a genuinely changed asset
/// (outcome [_TileCheckOutcome.updated]) -- mirroring [_fetchTile]'s own
/// cold-cache marking, so [_precacheSiblingSites] also fires after a
/// stale tile's real re-download, not only after a first-ever fetch
/// (GitHub Copilot review: a stale tile that revalidated to a genuinely
/// new asset version used to leave every sibling site unaware that lake's
/// shared maps now hold fresh, reusable data).
Future<BathymetryGrid?> _refreshIfStale(
  SwissBathy3dSource source,
  String tileKey,
  int tileE,
  int tileN,
  SwissLakeLevel lake,
  SwissBathyTileCacheEntry cached,
  _SharedFetchState shared,
  Map<String, Future<RawEsriGrid>> parsedEntries, {
  Map<String, SwissLakeLevel>? freshlyResolvedLakes,
}) async {
  final result = await _checkAndMaybeUpdate(
    source,
    tileKey,
    tileE,
    tileN,
    lake,
    cached,
    shared,
    parsedEntries,
  );
  if (result.outcome == _TileCheckOutcome.updated) {
    freshlyResolvedLakes?[lake.name] = lake;
  }
  return result.grid;
}

/// The same one-light-lookup, re-download-only-on-change check
/// [_refreshIfStale] performs, but reporting which of the three outcomes
/// happened rather than just the resulting grid — used by
/// `refreshAllCachedTiles()`, the manual "reload map data" action, to
/// build a summary of how many tiles were actually updated.
///
/// [shared]'s `zipBytes` memoizes each downloaded asset's BYTES by href, so
/// `refreshAllCachedTiles()` can pass in one shared across its whole sweep
/// — distinct cached tiles commonly share one href (one asset per lake,
/// see `swissbathy3d_source.dart`'s own class doc), and a version change
/// discovered while revalidating one of them would otherwise redundantly
/// re-download the exact same zip once per affected tile instead of once
/// per sweep — the same fair-use concern `fetch()`'s shared state already
/// addresses for the initial-fetch path.
///
/// [parsedEntries], unlike [shared], is NOT safe for `refreshAllCachedTiles`
/// to share across its whole sweep — see [_refreshAllCachedTilesImpl]'s own
/// doc for why that caller passes a fresh, single-tile-scoped map instead.
/// [_refreshIfStale] (the `fetch()`-time path), by contrast, passes its
/// caller's own single-lake-scoped map, exactly like [shared].
Future<({BathymetryGrid? grid, _TileCheckOutcome outcome})>
_checkAndMaybeUpdate(
  SwissBathy3dSource source,
  String tileKey,
  int tileE,
  int tileN,
  SwissLakeLevel lake,
  SwissBathyTileCacheEntry cached,
  _SharedFetchState shared,
  Map<String, Future<RawEsriGrid>> parsedEntries,
) async {
  Future<List<RawEsriGrid>> download(String href) => _downloadAndParseFiltered(
    source,
    href,
    tileE,
    tileN,
    shared,
    parsedEntries,
  );
  final List<SwissBathyAsset> candidates;
  try {
    candidates = await _findAssetCandidatesForLake(source, lake, shared);
  } on SwissStacException {
    // metadata lookup failed -- retry on next check
    return (grid: cached.grid, outcome: _TileCheckOutcome.failed);
  } on BathymetryFetchException {
    // no known collection id resolved right now
    return (grid: cached.grid, outcome: _TileCheckOutcome.failed);
  }

  // Match by href, not list position: the candidate whose content
  // actually covers this tile is not necessarily candidates.first (see
  // _firstOverlappingCandidate's doc) and that order is not guaranteed
  // stable across requests either. Comparing an unrelated candidate's
  // datetime against cached.sourceDatetime would report "changed" for two
  // assets that were never the same thing to begin with, forcing a real
  // download on every single check. Matching back to the exact
  // previously-covering href keeps the check just as cheap (still only
  // the light items lookup above, no asset download) while actually
  // comparing the right two datetimes.
  // Records that this check happened without changing the cached grid --
  // shared by all three "nothing to update" outcomes below, which
  // otherwise only differ in which datetime they touch the row with.
  Future<({BathymetryGrid? grid, _TileCheckOutcome outcome})> stillUpToDate(
    String? sourceDatetime,
  ) async {
    await source._tileCache.touch(tileKey, sourceDatetime: sourceDatetime);
    return (grid: cached.grid, outcome: _TileCheckOutcome.upToDate);
  }

  final previousHref = cached.sourceHref;
  SwissBathyAsset? matched;
  if (previousHref != null) {
    for (final candidate in candidates) {
      if (candidate.href == previousHref) {
        matched = candidate;
        break;
      }
    }
  }
  if (matched != null && matched.datetime == cached.sourceDatetime) {
    // Same asset, same version: nothing to update, just record that the
    // check happened, so the next one is due again in staleCheckInterval.
    return stillUpToDate(matched.datetime);
  }

  // Either the previously-covering asset changed version, or it is no
  // longer among the current candidates (renamed/replaced), or this row
  // predates sourceHref (v15 and earlier) and has never been matched yet.
  // None of those can be told apart from metadata alone, so fall through
  // to a real re-resolution -- the one-time cost self-heals a pre-v16 row
  // onto its href for every check after this one.
  try {
    final resolved = await _firstOverlappingCandidate(
      tileE,
      tileN,
      candidates,
      download,
    );
    if (resolved == null) {
      // None of the candidates' actual content covers this tile --
      // nothing usable to update to, so just record the check happened.
      return await stillUpToDate(cached.sourceDatetime);
    }
    if (resolved.asset.href == previousHref &&
        resolved.asset.datetime == cached.sourceDatetime) {
      // Only reachable when the href-based shortcut above could not run
      // (no stored href yet) but re-resolution landed on the exact same
      // asset and version anyway -- still no update needed.
      return await stillUpToDate(resolved.asset.datetime);
    }
    final grid = parseSwissLv95RawGrid(
      resolved.subRaw,
      sourceId: SwissBathy3dSource.sourceId,
      fetchedAt: DateTime.now(),
      referenceLevelMeters: lake.meanLevelMeters,
    );
    await source._tileCache.writeOk(
      tileKey,
      grid,
      sourceDatetime: resolved.asset.datetime,
      sourceHref: resolved.asset.href,
      referenceLevelMeters: lake.meanLevelMeters,
    );
    return (grid: grid, outcome: _TileCheckOutcome.updated);
  } on SwissStacException {
    return (grid: cached.grid, outcome: _TileCheckOutcome.failed);
  } on FormatException {
    return (grid: cached.grid, outcome: _TileCheckOutcome.failed);
  }
}

/// Immediately revalidates every currently cached tile's freshness,
/// bypassing [SwissBathy3dSource.staleCheckInterval] — the manual "reload
/// map data" action's entry point. Reuses [_checkAndMaybeUpdate], the
/// exact same light STAC item lookup with conditional re-download the
/// periodic per-fetch check performs, so this never re-downloads a tile
/// whose version has not actually changed. A tile whose check fails
/// (offline, STAC error) keeps serving its existing cached grid unchanged,
/// counted as [SwissBathyRefreshSummary.failed] rather than thrown — one
/// failed tile must not abort the sweep over the rest, matching the
/// fair-use requirement that a failed check never becomes a crash or a
/// forced re-download loop. Uses the same
/// [SwissBathy3dSource.maxConcurrentTileRequests]-bounded concurrency as
/// `fetch()`'s tile-stitching loop, rather than an independent sequential
/// or unbounded sweep, so a large cache (many visited lakes) revalidates
/// quickly without exceeding the same fair-use-driven concurrency
/// ceiling.
///
/// Distinct cached tiles routinely share one STAC asset href (one asset
/// per lake, not per tile — see `swissbathy3d_source.dart`'s own class
/// doc), so [_SharedFetchState] memoizes the downloaded bytes by href
/// across the whole sweep, exactly like `fetch()`'s own shared state does
/// for the initial-fetch path: a version change discovered on one tile of
/// a lake re-downloads that lake's zip at most once for the entire sweep,
/// not once per affected tile.
///
/// The decompress-and-parse step per zip entry ([_parsedEntry]) does NOT
/// get this same sweep-wide sharing, unlike [shared] above — this sweep
/// can touch every tile ever cached, across every lake the diver has ever
/// visited, not one lake's own span like `fetch()`. Sharing parsed grids
/// at that scope would let several large lakes' fully decompressed grids
/// (Bodensee alone: 751 entries, 237 MB uncompressed — see the class doc)
/// accumulate in memory simultaneously whenever a sweep happens to
/// re-resolve more than one of them, resurrecting the exact "time out or
/// crash on a phone" failure mode `_entriesNearTile`'s own filtering
/// exists to prevent (code review on this very sharing mechanism). Each
/// tile below is therefore given its own, single-tile-scoped map instead
/// — the decompress/parse step for THIS sweep runs exactly as
/// unshared-per-tile as it always did before entry-parse memoization
/// existed at all; only the metadata lookup and the raw zip bytes get the
/// sweep-wide sharing `fetch()` also gets.
Future<SwissBathyRefreshSummary> _refreshAllCachedTilesImpl(
  SwissBathy3dSource source,
) async {
  final tileKeys = await source._tileCache.allTileKeys();

  final shared = _SharedFetchState();

  final outcomes = await _runBounded(
    tileKeys,
    SwissBathy3dSource.maxConcurrentTileRequests,
    (tileKey) async {
      final parts = tileKey.split('_');
      final tileE = parts.length == 2 ? int.tryParse(parts[0]) : null;
      final tileN = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (tileE == null || tileN == null) return null;

      final lake = findSwissLake(_tileCenterWgs84(tileE, tileN));
      if (lake == null) {
        // The tile's OWN center resolves to no current lake, but the row
        // may still be one fetch() cached under the FETCH CENTER's lake
        // as a fallback (a real edge tile whose own center misses every
        // registered bbox -- see fetch()'s tileLake fallback), so there is
        // no single current lake to pass to read()'s normal per-lookup
        // check. Delete it only if its stored level belongs to no lake in
        // the CURRENT table at all -- the actual staleness signal a lake
        // removal or a documented level correction leaves behind (Copilot
        // review).
        await source._tileCache.deleteIfLevelUnknown(
          tileKey,
          swissLakeLevels.map((l) => l.meanLevelMeters),
        );
        return null;
      }

      // Computed BEFORE the read so a reference-level mismatch (the lake
      // table changed since this tile was cached) is caught here too, not
      // just on the next fetch() visit -- read() drops the row and
      // returns null in that case, same as corruption. Applies uniformly
      // to an 'ok' row (dropped, so the next fetch() re-downloads) and an
      // 'empty' one (dropped, so the next fetch() re-resolves instead of
      // hasCachedAnswer() suppressing it forever) -- see allTileKeys' doc
      // for why 'empty' tiles are included in this sweep at all. A
      // still-valid 'empty' row also reads back null here (it never
      // carries a grid), so this branch covers "nothing to check" and
      // "just invalidated" alike; neither needs the freshness check
      // below.
      final cached = await source._tileCache.read(
        tileKey,
        expectedReferenceLevelMeters: lake.meanLevelMeters,
      );
      if (cached == null) {
        return null;
      }

      final result = await _checkAndMaybeUpdate(
        source,
        tileKey,
        tileE,
        tileN,
        lake,
        cached,
        shared,
        <String, Future<RawEsriGrid>>{},
      );
      return result.outcome;
    },
  );

  var updated = 0;
  var upToDate = 0;
  var failed = 0;
  for (final outcome in outcomes) {
    switch (outcome) {
      case _TileCheckOutcome.updated:
        updated++;
      case _TileCheckOutcome.upToDate:
        upToDate++;
      case _TileCheckOutcome.failed:
        failed++;
      case null:
        break; // evicted, corrupted, or unparseable tile key: not counted
    }
  }
  return SwissBathyRefreshSummary(
    updated: updated,
    upToDate: upToDate,
    failed: failed,
  );
}

/// The result of one tile's freshness check in [_checkAndMaybeUpdate].
enum _TileCheckOutcome { updated, upToDate, failed }

/// Tally of a [SwissBathy3dSource.refreshAllCachedTiles] sweep, for the
/// manual "reload map data" action's confirmation message.
class SwissBathyRefreshSummary {
  /// Tiles whose STAC version had genuinely changed and were re-downloaded.
  final int updated;

  /// Tiles checked and confirmed to already be the latest version.
  final int upToDate;

  /// Tiles whose check itself failed (offline, STAC error) — these kept
  /// serving their existing cached grid unchanged, never counted as an
  /// error the user needs to act on.
  final int failed;

  const SwissBathyRefreshSummary({
    required this.updated,
    required this.upToDate,
    required this.failed,
  });

  /// Tiles the sweep reached a verdict on. Excludes cached rows it skipped
  /// without checking (an evicted, corrupt or unparseable key yields no
  /// outcome), so this can be lower than the row count at the start of the
  /// sweep and must not be read as "everything that was cached".
  int get total => updated + upToDate + failed;
}
