part of 'swissbathy3d_source.dart';

/// Ensures every known dive site's own swissBATHY3D tile is cached, one
/// lake at a time -- so the underlying zip asset is downloaded and its
/// relevant entries decompressed at most once PER LAKE for this call, not
/// once per site.
///
/// [SwissBathy3dSource.fetch]'s own per-call [_SharedFetchState] already
/// reuses that work across every tile ONE call touches, and
/// [_precacheSiblingSites] extends the reuse to sibling sites too -- but
/// only fire-and-forget and unawaited, deliberately throttled to
/// [SwissBathy3dSource.maxConcurrentPrecacheRequests] so it never contends
/// with whatever the diver is looking at right now (see that constant's own
/// doc). A caller working through MANY known sites in a tight, sequential
/// loop -- the "3D Maps" settings page's reload action -- easily outpaces
/// that background sweep: by the time the loop reaches a sibling site, its
/// precache pass has often not even started, let alone finished, so the
/// loop's own `fetch()` call for that site pays for a from-scratch zip
/// download and decompress instead of reusing what a previous site on the
/// SAME lake already pulled down moments earlier -- exactly the
/// multi-second-per-tile cost [SwissBathy3dSource]'s own class doc
/// describes for a single such entry set.
///
/// [_warmKnownSitesImpl] is the deterministic fix: called explicitly and
/// awaited BEFORE the caller's own per-site loop, grouped by lake with one
/// fresh [_SharedFetchState] (and one parsed-entry cache) per lake -- the
/// same bounded-to-one-lake memory shape [SwissBathy3dSource.fetch] already
/// uses for its own span, never shared across the whole run the way
/// [_refreshAllCachedTilesImpl]'s sweep deliberately is NOT (see
/// [_SharedFetchState]'s own doc on why). By the time the caller's own loop
/// reaches a Swiss lake site, its tile is normally already warm and its
/// `fetch()` call resolves from [SwissBathyTileCacheRepository] alone.
///
/// Reuses [SwissBathy3dSource._fetchTile] exactly as [_precacheSiblingSites]
/// already does -- no change to that well-tested per-tile logic, only to
/// when and how it is driven.
///
/// [isCancelled], if given, is checked BETWEEN lakes (never mid-download —
/// a lake already in flight still finishes, matching the same in-flight
/// caveat [MapReloadNotifier.cancel] documents for the caller's own
/// per-site loop): once it returns true, no further lake is started. Logs
/// each lake it starts and how many tiles it holds, since this whole pass
/// is otherwise silent CPU/network work with nothing else in the app
/// logging anything for its duration -- without this, a diver watching the
/// debug log during a long reload sees no activity for however long the
/// warm pass takes and reasonably assumes the app has hung.
///
/// [onLakeStart], if given, is called with the same information right
/// before each lake starts (name, its 1-based position, and the total lake
/// count) -- the UI-facing counterpart of the log line above, since the
/// reload progress card has no other way to show that it is working
/// through this phase at all (its own site counter stays at zero the whole
/// time this runs).
Future<void> _warmKnownSitesImpl(
  SwissBathy3dSource source, {
  bool Function()? isCancelled,
  void Function(String lakeName, int index, int total)? onLakeStart,
}) async {
  final knownSiteLocations = source._knownSiteLocations;
  if (knownSiteLocations == null) return;
  final List<GeoPoint> sites;
  try {
    sites = await knownSiteLocations();
  } catch (_) {
    return;
  }

  // Keyed by tile, same as _precacheSiblingSites, so two sites that floor
  // to the same 1-km cell warm it once, not twice. Grouped by lake name so
  // each lake gets its own bounded shared state below.
  final tilesByLake = <String, Map<String, ({int tileE, int tileN})>>{};
  final lakesByName = <String, SwissLakeLevel>{};
  for (final site in sites) {
    try {
      final lv95 = Lv95Transform.fromWgs84(site.latitude, site.longitude);
      final tileE = (lv95.easting / SwissBathy3dSource.tileSizeMeters).floor();
      final tileN = (lv95.northing / SwissBathy3dSource.tileSizeMeters).floor();
      final tileLake =
          findSwissLake(_tileCenterWgs84(tileE, tileN)) ?? findSwissLake(site);
      if (tileLake == null) continue;
      lakesByName[tileLake.name] = tileLake;
      (tilesByLake[tileLake.name] ??= {})['${tileE}_$tileN'] = (
        tileE: tileE,
        tileN: tileN,
      );
    } catch (_) {
      // One site's own bad coordinates must not abort warming every other
      // known site's lake, exactly like _precacheSiblingSites tolerates it.
    }
  }

  _log.info(
    'warmKnownSites: ${sites.length} known site(s) resolve to '
    '${tilesByLake.length} swissBATHY3D lake(s)',
  );

  final lakeNames = tilesByLake.keys.toList();
  for (var i = 0; i < lakeNames.length; i++) {
    final lakeName = lakeNames[i];
    if (isCancelled?.call() ?? false) {
      _log.info('warmKnownSites: cancelled before lake $lakeName');
      return;
    }
    final lake = lakesByName[lakeName]!;
    final tiles = tilesByLake[lakeName]!.values.toList();
    _log.info(
      'warmKnownSites: warming lake $lakeName (${tiles.length} tile(s))',
    );
    onLakeStart?.call(lakeName, i + 1, lakeNames.length);
    final shared = _SharedFetchState();
    final parsedEntries = <String, Future<RawEsriGrid>>{};
    await _runBounded(tiles, SwissBathy3dSource.maxConcurrentTileRequests, (
      tile,
    ) async {
      try {
        await source._fetchTile(
          tile.tileE,
          tile.tileN,
          lake,
          shared,
          parsedEntries,
        );
      } catch (_) {
        // One tile's failure must not abort the rest of the lake/run; the
        // caller's own later fetch() for that site retries it normally.
      }
    });
  }
  _log.info('warmKnownSites: finished warming ${tilesByLake.length} lake(s)');
}
