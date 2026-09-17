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
/// through the same [SwissBathy3dSource.maxConcurrentTileRequests]-bounded
/// pool ([_runBounded]) already enforced everywhere else in this class,
/// rather than each lake's pass running as its own uncapped, concurrent
/// side quest alongside the others.
Future<void> _precacheSiblingSites(
  SwissBathy3dSource source,
  Iterable<SwissLakeLevel> lakes,
  Map<String, Future<Uint8List>> sharedZipBytes,
  Map<String, Future<List<SwissBathyAsset>>> sharedCandidates,
) async {
  final knownSiteLocations = source._knownSiteLocations;
  if (knownSiteLocations == null) return;
  final List<GeoPoint> sites;
  try {
    sites = await knownSiteLocations();
  } catch (_) {
    return;
  }

  final lakesByName = {for (final lake in lakes) lake.name: lake};
  final siblingTiles = <({int tileE, int tileN, SwissLakeLevel lake})>[];
  for (final site in sites) {
    final lake = lakesByName[findSwissLake(site)?.name];
    if (lake == null) continue;
    final lv95 = Lv95Transform.fromWgs84(site.latitude, site.longitude);
    siblingTiles.add((
      tileE: (lv95.easting / SwissBathy3dSource.tileSizeMeters).floor(),
      tileN: (lv95.northing / SwissBathy3dSource.tileSizeMeters).floor(),
      lake: lake,
    ));
  }
  if (siblingTiles.isEmpty) return;

  await _runBounded(
    siblingTiles,
    SwissBathy3dSource.maxConcurrentTileRequests,
    (tile) async {
      try {
        await source._fetchTile(
          tile.tileE,
          tile.tileN,
          tile.lake,
          sharedZipBytes,
          sharedCandidates,
        );
      } catch (_) {
        // Best-effort: this site's own future visit will resolve and cache
        // it normally, exactly as if this pre-cache pass never ran.
      }
    },
  );
}
