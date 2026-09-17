part of 'swissbathy3d_source.dart';

/// Every dive site coordinate already known to the app, regardless of which
/// diver logged it -- used only to opportunistically pre-cache OTHER sites
/// on a lake whose asset [SwissBathy3dSource.fetch] just downloaded anyway
/// (see [_precacheSiblingSites]). Optional at the call site: null (the
/// default) means "don't bother", and the normal per-visit fetch path is
/// unaffected either way -- this is a pure cache-warming bonus, never
/// load-bearing for a caller's own result.
typedef KnownDiveSiteLocations = Future<List<GeoPoint>> Function();

/// Opportunistically caches every other locally KNOWN dive site's own tile
/// within any of [lakes], reusing the candidates/zip bytes [source]'s
/// `fetch()` already resolved for the tile(s) that triggered this call --
/// no extra network request beyond what that call already made for a lake
/// it already has data for. Called fire-and-forget from `fetch()`; every
/// failure here -- a failed [SwissBathy3dSource._knownSiteLocations]
/// lookup, or one particular site's own [SwissBathy3dSource._fetchTile]
/// call -- is swallowed, exactly like the manual "reload map data" sweep's
/// per-tile failures, since this is a pure cache-warming bonus, never
/// load-bearing for `fetch()`'s own caller.
///
/// Addresses #1764's follow-up: without this, visiting a NEW, previously
/// unvisited dive site on an already-downloaded lake re-downloads the whole
/// (sometimes 100+ MB) lake asset again, even though every cell this app
/// will ever need from it for that site was already sitting in memory
/// once, moments earlier, for a different site on the same lake.
///
/// Takes every lake `fetch()` touched in ONE call, not one call per lake:
/// the known-site lookup runs exactly once regardless of how many lakes a
/// wide span reached, and every sibling tile this resolves is funneled
/// through [SwissBathy3dSource.maxConcurrentPrecacheRequests]'s OWN,
/// deliberately smaller pool ([_runBounded]) — see that constant's doc for
/// why this fire-and-forget background sweep must never contend with a
/// concurrently running foreground [SwissBathy3dSource.fetch]/
/// [SwissBathy3dSource.refreshAllCachedTiles] call for the same
/// [maxConcurrentTileRequests] worker slots.
Future<void> _precacheSiblingSites(
  SwissBathy3dSource source,
  Iterable<SwissLakeLevel> lakes,
  _SharedFetchState shared,
  Map<String, Future<RawEsriGrid>> parsedEntries,
) async {
  final knownSiteLocations = source._knownSiteLocations;
  if (knownSiteLocations == null) return;
  final List<GeoPoint> sites;
  try {
    sites = await knownSiteLocations();
  } catch (_) {
    return;
  }

  final lakeNames = {for (final lake in lakes) lake.name};
  // Keyed by tile so two sites that floor to the same 1-km cell (two
  // buddies' GPS for the same dive, or simply two nearby sites) dispatch
  // one _fetchTile call, not one each racing to write the same row
  // (Copilot review).
  final siblingTiles =
      <String, ({int tileE, int tileN, SwissLakeLevel lake})>{};
  for (final site in sites) {
    try {
      final lv95 = Lv95Transform.fromWgs84(site.latitude, site.longitude);
      final tileE = (lv95.easting / SwissBathy3dSource.tileSizeMeters).floor();
      final tileN = (lv95.northing / SwissBathy3dSource.tileSizeMeters).floor();
      // Resolved the same way fetch() resolves every tile's own lake
      // (tile-center first, the site's own point only as a fallback for a
      // tile whose center misses every registered bbox) rather than the
      // site's raw point alone -- otherwise a site near a real
      // lake-boundary overlap could get cached here under a different
      // lake (and so a different reference level) than a real visit to
      // that same tile would resolve via fetch(), self-healing on that
      // later visit but wasting this pre-cache attempt in the meantime
      // (Copilot review).
      final tileLake =
          findSwissLake(_tileCenterWgs84(tileE, tileN)) ?? findSwissLake(site);
      if (tileLake == null || !lakeNames.contains(tileLake.name)) continue;
      siblingTiles['${tileE}_$tileN'] = (
        tileE: tileE,
        tileN: tileN,
        lake: tileLake,
      );
    } catch (_) {
      // One site's own bad coordinates (e.g. a corrupted lat/lon row)
      // must not abort pre-caching for every OTHER known site in this
      // call -- exactly like the per-tile fetch loop below already
      // tolerates one tile's failure without affecting its siblings.
    }
  }
  if (siblingTiles.isEmpty) return;

  await _runBounded(
    siblingTiles.values.toList(),
    SwissBathy3dSource.maxConcurrentPrecacheRequests,
    (tile) async {
      try {
        await source._fetchTile(
          tile.tileE,
          tile.tileN,
          tile.lake,
          shared,
          parsedEntries,
        );
      } catch (_) {
        // Best-effort: this site's own future visit will resolve and cache
        // it normally, exactly as if this pre-cache pass never ran.
      }
    },
  );
}
