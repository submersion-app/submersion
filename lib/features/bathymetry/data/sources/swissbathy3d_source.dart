import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/lv95_transform.dart';
import 'package:submersion/features/bathymetry/data/sources/esri_ascii_parser.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lake_levels.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lv95_grid.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_stac_client.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

part 'swissbathy3d_sibling_precache.dart';
part 'swissbathy3d_resolution.dart';
part 'swissbathy3d_freshness.dart';

const _log = LoggerService('SwissBathy3dSource');

/// Regional tier: swisstopo swissBATHY3D lake-bed elevation model, via the
/// STAC API on data.geo.admin.ch (OGD, "Freie Nutzung, Quellenangabe ist
/// Pflicht" — attribution is Part 2's concern, not fetched here).
///
/// Z values in the source grid are heights above sea level (LN02), NOT
/// depths, and the grid itself is in LV95 meters, not WGS84 degrees —
/// [parseSwissLv95Grid] handles both conversions, using each lake's mean
/// water level from [swissLakeLevels].
///
/// Covers only the lakes in [swissLakeLevels] (a coordinate elsewhere in
/// Switzerland is dry land, out of scope for a bathymetry source). Each
/// covered coordinate maps to exactly one LV95 1-km tile, cached by
/// [SwissBathyTileCacheRepository] so a tile's data is downloaded at most
/// once, per the OGD fair-use requirement.
///
/// A single STAC asset is not necessarily scoped to one 1-km tile — a live
/// check found swisstopo instead publishes one asset per LAKE (e.g. all of
/// Walensee in one "swissbathy3d_walensee" zip). [_fetchTile] downloads
/// that asset's bytes once per asset href (shared across every tile
/// coordinate that resolves to it, via [fetch]'s `sharedZipBytes`), then
/// each tile independently parses and slices out just its own cells with
/// [extractRawEsriSubgridFromGrids] before caching — without that slicing
/// step, every tile in the same lake would cache and stitch the exact same
/// whole-lake grid regardless of its own coordinates.
///
/// Nor is a lake's zip guaranteed to contain a single grid file itself — a
/// further live check found the downloaded asset's own `.asc`/`.grd` file
/// can describe only a ~1-km sub-area of the lake (swisstopo's own internal
/// tiling inside the archive), with the zip containing several such entries
/// that together cover the whole lake. Reading only the zip's first
/// matching entry meant nearly every requested tile fell outside that one
/// entry's footprint and came back as a false "no data" gap, except the one
/// coincidentally aligned with it (Bug 15) — [extractGridZipTextsFiltered]
/// reads every entry plausibly near the requested tile (see its own doc),
/// and [_downloadAndParseFiltered] parses all of them, so
/// [extractRawEsriSubgridFromGrids] can search across that set.
///
/// A STAC item's declared `bbox` overlapping a tile's query is not proof its
/// actual raster does too (the declared bbox can be coarser, or simply
/// wrong, relative to the file's own header) — trusting only the first
/// bbox-plausible candidate meant one such candidate could silently starve
/// every tile query it happened to satisfy, well within a lake's real
/// coverage. [_firstOverlappingCandidate] tries every candidate STAC
/// returned for a tile's bbox, in order, and keeps the first whose
/// downloaded content genuinely slices a non-empty
/// [extractRawEsriSubgridFromGrids] result — only when none do is the tile
/// treated as a real gap.
///
/// A lake-wide asset zip is not necessarily small: a live check found some
/// lakes' zips hold hundreds of internal entries and hundreds of MB
/// uncompressed (Bodensee: 751 entries, 237 MB zip). Parsing every entry to
/// answer one tile query made large lakes slow enough, and memory-heavy
/// enough, to time out or crash on a phone. [extractGridZipTextsFiltered]
/// only decompresses entries whose filename-declared tile is within one
/// tile of the one actually being resolved (a live check across every
/// lake in [swissLakeLevels] confirmed each entry's name encodes its own
/// `xllcorner`/`yllcorner` truncated to the kilometre); an entry whose name
/// does not match that pattern is still always included, so an unexpected
/// naming scheme degrades to the slower-but-correct unfiltered behaviour
/// rather than silently dropping data. This filtering happens per tile,
/// independently — [_downloadAndParseFiltered] shares only the downloaded
/// zip BYTES across tiles in one [fetch] call (via `sharedZipBytes`), never
/// the parsed/filtered entries, because two tiles sharing one href can
/// legitimately need different entries out of it; sharing the filtered
/// result would silently starve whichever tile's entries were not part of
/// the first tile's own neighborhood — the Bug 15 failure mode one layer
/// deeper.
class SwissBathy3dSource implements BathymetrySource {
  static const String sourceId = 'swissbathy3d';
  static const double tileSizeMeters = 1000;

  /// How long a cached tile is served without a freshness check. Chosen to
  /// keep the periodic check rare — swissBATHY3D lakes are re-surveyed on
  /// the order of years, not days — while still noticing an update within a
  /// bounded time. A stale tile still costs at most one light STAC item
  /// lookup, never a re-download unless the version actually changed (see
  /// [_refreshIfStale]), so this does not multiply the up-to-81-tile cost a
  /// single wide-span page view can already trigger (see fetch()).
  static const Duration staleCheckInterval = Duration(days: 30);

  /// Caps how many tiles are fetched or freshness-checked at once, in both
  /// [fetch]'s stitching loop and [refreshAllCachedTiles]'s sweep. A wide
  /// span can touch up to 81 tiles (see [staleCheckInterval]'s doc);
  /// fetching them strictly one at a time made a single page view painfully
  /// slow, but firing all of them at once would hammer the OGD server and
  /// violate its fair-use clause against excessive use just as surely as an
  /// unbounded download loop would. Bounded concurrency is the middle
  /// ground; this is a named constant rather than a magic number so both
  /// call sites stay in lockstep with each other and with the design intent.
  static const int maxConcurrentTileRequests = 4;

  /// Nominal grid spacing swissBATHY3D publishes for lake bathymetry.
  /// Declared, not measured, per [SourceCapability]'s contract -- the actual
  /// per-tile [BathymetryGrid.resolutionMeters] comes from each tile's own
  /// ESRI ASCII header once fetched, and can be finer.
  static const double declaredCellSizeMeters = 2.0;

  final SwissStacClient _stac;
  final SwissBathyTileCacheRepository _tileCache;
  final KnownDiveSiteLocations? _knownSiteLocations;

  SwissBathy3dSource({
    required SwissBathyTileCacheRepository tileCache,
    http.Client? httpClient,
    SwissStacClient? stacClient,
    KnownDiveSiteLocations? knownSiteLocations,
  }) : _tileCache = tileCache,
       _stac = stacClient ?? SwissStacClient(client: httpClient),
       _knownSiteLocations = knownSiteLocations;

  @override
  String get id => sourceId;

  @override
  bool get global => false;

  /// 0, not the resolver default (see [BathymetrySource.minKnownFraction]'s
  /// doc): a coordinate reaches this source only after [covers] already
  /// confirmed it sits inside a real, listed Swiss lake, so a cell this
  /// source leaves unknown within the requested span is confirmed dry
  /// land (a real STAC lookup found no covering tile there), not an
  /// uncertain survey gap. [BathymetryResolver.minWetFraction]'s floor on
  /// [BathymetryGrid.wetFraction] -- effectively 100% here, since every
  /// known cell in a swissBATHY3D grid is a real lake-bed reading -- is
  /// what actually guards against a spurious near-empty grid; this floor
  /// would only reject genuine, narrow-lake dive sites (Walensee,
  /// Vierwaldstättersee's fjord-like bays) whose real coverage is
  /// legitimately a small fraction of an 8 km square request.
  @override
  double get minKnownFraction => 0.0;

  /// Not part of [BathymetrySource] -- a synchronous, no-network check used
  /// by [SwissLakeDepthService] and [BathymetryRepository.quantumDegFor],
  /// which need an answer ahead of (and independent from) the resolver's
  /// [probe]/fetch cycle.
  bool covers(GeoPoint center) => findSwissLake(center) != null;

  @override
  Future<SourceCapability?> probe(GeoPoint center) async {
    if (!covers(center)) return null;
    return const SourceCapability(
      cellSizeMeters: declaredCellSizeMeters,
      detail: 'swissBATHY3D',
    );
  }

  /// The LV95 1-km tile index (e.g. "2600_1200") containing [lv95].
  static String tileKeyFor(Lv95Coordinates lv95) {
    final tileE = (lv95.easting / tileSizeMeters).floor();
    final tileN = (lv95.northing / tileSizeMeters).floor();
    return '${tileE}_$tileN';
  }

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final lake = findSwissLake(center);
    if (lake == null) {
      throw const BathymetryFetchException(
        'coordinate outside known Swiss lakes',
      );
    }

    final lv95 = Lv95Transform.fromWgs84(center.latitude, center.longitude);
    final half = spanMeters / 2;
    final tileEMin = ((lv95.easting - half) / tileSizeMeters).floor();
    final tileEMax = ((lv95.easting + half) / tileSizeMeters).floor();
    final tileNMin = ((lv95.northing - half) / tileSizeMeters).floor();
    final tileNMax = ((lv95.northing + half) / tileSizeMeters).floor();

    final tileCoords = <({int tileE, int tileN})>[
      for (var tileN = tileNMin; tileN <= tileNMax; tileN++)
        for (var tileE = tileEMin; tileE <= tileEMax; tileE++)
          (tileE: tileE, tileN: tileN),
    ];

    // Distinct 1-km tile coordinates can legitimately resolve to the exact
    // same STAC asset href -- confirmed live: swisstopo publishes one asset
    // per LAKE, not per tile, so every tile coordinate within a lake shares
    // one href. Memoized per fetch() call on the DOWNLOADED BYTES (not the
    // parsed result -- see this class's own doc for why sharing parsed,
    // filtered entries across tiles is unsafe) so that shared, potentially
    // lake-sized zip travels over the network exactly once, not once per
    // tile coordinate that happens to resolve to it. Each tile still parses
    // and slices its own, location-correct entries independently in
    // _fetchTile.
    final sharedZipBytes = <String, Future<Uint8List>>{};

    // Same sharing, one step earlier: every tile of the SAME lake asks the
    // STAC items endpoint the identical "which asset covers this?" question
    // and gets the identical one-item answer back (#1764) -- an 8 km span
    // touching up to 81 tiles used to fire up to 81 near-identical metadata
    // lookups for an answer that never varies within a lake, each on its
    // own 15 s budget. A single slow or transiently failed lookup among
    // those 81 was enough to fail the whole span; see
    // [_findAssetCandidatesForLake]'s doc.
    final sharedCandidates = <String, Future<List<SwissBathyAsset>>>{};

    // Bounded concurrency, not strictly sequential nor unbounded: up to
    // maxConcurrentTileRequests tiles in flight at once. Each is
    // cache-checked before any network call, so a warm cache stays cheap;
    // for a cold cache spanning dozens of tiles, this keeps a single page
    // view from either taking minutes (one at a time) or hammering the OGD
    // server with dozens of simultaneous requests.
    final failedTileKeys = <String>[];
    // Every distinct lake actually touched while resolving this span's
    // tiles, collected so _precacheSiblingSites can run once per lake
    // afterwards -- see that method's doc and the call site below.
    final lakesTouched = <String, SwissLakeLevel>{};
    // Lake names _fetchTile actually did fresh work for (not served purely
    // from cache) -- see that method's own doc on this parameter. Gates
    // the precache call below so a fully-cached fetch() (the common case
    // on a lake, per BathymetryRepository's own doc on why lake
    // coordinates skip outer-cell quantization) never pays for a
    // known-site-locations lookup it has nothing to reuse for.
    final freshlyResolvedLakes = <String>{};
    final results = await _runBounded(tileCoords, maxConcurrentTileRequests, (
      coord,
    ) async {
      try {
        // The lake resolved at the fetch CENTER is only a default: an 8 km
        // span can reach tiles that actually belong to a different,
        // overlapping-bbox lake (e.g. Rotsee vs. Vierwaldstättersee), whose
        // mean water level can differ by 10+ m. Re-resolving per tile keeps
        // each tile's LN02-to-depth conversion honest; falling back to the
        // center's lake only for a tile whose own center misses every
        // registered bbox (a real edge tile of the requested lake).
        final tileLake =
            findSwissLake(_tileCenterWgs84(coord.tileE, coord.tileN)) ?? lake;
        lakesTouched[tileLake.name] = tileLake;
        return await _fetchTile(
          coord.tileE,
          coord.tileN,
          tileLake,
          sharedZipBytes,
          sharedCandidates,
          freshlyResolvedLakes: freshlyResolvedLakes,
        );
      } on BathymetryFetchException catch (e) {
        // Individually harmless -- the failed tile's own cache stays
        // untouched (see _fetchTile), so a retry only re-downloads that
        // one tile, and every OTHER tile's successful download is already
        // durably cached by this point regardless of what happens next.
        // But this fetch's own RETURN VALUE must not silently swallow the
        // failure into an indistinguishable-from-real-shoreline null: with
        // minKnownFraction at 0.0 (see this class's own override -- every
        // null this source returns is supposed to be a confirmed land
        // fact), a span with only a couple of successful wet tiles among
        // dozens of transiently-failed ones would otherwise pass every
        // floor and get cached by the outer repository as a complete,
        // definitive 'ok' answer, permanently starving the failed tiles of
        // ever being retried (Copilot review). failedTileKeys flags that
        // below instead -- and, unlike a bare boolean, also captures WHICH
        // tile(s) and the underlying [e] (network error, HTTP status, or
        // timeout) that fetch()'s own caller would otherwise never see:
        // BathymetryFetchException's message alone used to reach no log at
        // all once it got here.
        _log.warning('tile ${coord.tileE}_${coord.tileN} failed', error: e);
        failedTileKeys.add('${coord.tileE}_${coord.tileN}');
        return null;
      }
    });
    final tiles = [for (final tile in results) ?tile];

    // Fire-and-forget, deliberately not awaited (.ignore() suppresses the
    // unawaited-future lint and any unhandled-error crash report): this is
    // a pure cache-warming bonus for OTHER dive sites on the same lake(s),
    // reusing the zip bytes/candidates already in memory from the tiles
    // above, so it must never delay -- or, via some future refactor,
    // accidentally fail -- the result this call actually promised its
    // caller. Placed before the failure checks below so it still runs
    // (for whichever lake(s) DID resolve) even when this span itself is
    // about to throw. One call covering every FRESHLY resolved lake, not
    // one per lake and not for every touched lake regardless of outcome
    // (see freshlyResolvedLakes' own doc): the known-site lookup runs at
    // most once per fetch() call, only when there is genuinely new
    // in-memory data worth reusing, and every sibling tile still shares
    // [maxConcurrentTileRequests] with the rest of this class instead of
    // running as its own uncapped, concurrent side quest -- see
    // [_precacheSiblingSites]'s own doc.
    if (freshlyResolvedLakes.isNotEmpty) {
      _precacheSiblingSites(
        this,
        [for (final name in freshlyResolvedLakes) lakesTouched[name]!],
        sharedZipBytes,
        sharedCandidates,
      ).ignore();
    }

    if (failedTileKeys.isNotEmpty) {
      // Whatever DID succeed is already sitting in the per-tile cache, so
      // this costs a retry of only the tiles that actually failed, not a
      // re-download of the whole span -- see the catch block above.
      throw BathymetryFetchException(
        '${failedTileKeys.length} of ${tileCoords.length} tiles in span '
        'failed transiently E[$tileEMin..$tileEMax] N[$tileNMin..$tileNMax]: '
        '${failedTileKeys.join(', ')}',
      );
    }

    if (tiles.isEmpty) {
      throw BathymetryFetchException(
        'no swissBATHY3D tiles for tile range '
        'E[$tileEMin..$tileEMax] N[$tileNMin..$tileNMax]',
      );
    }
    return tiles.length == 1 ? tiles.single : _stitchTiles(tiles);
  }

  /// Fetches, parses and caches the single 1-km tile at ([tileE], [tileN]),
  /// or returns null when swissBATHY3D genuinely has no tile there (e.g. a
  /// shoreline cell outside the "complete tiles only" coverage) — a gap to
  /// stitch around, not an error. Transient failures (network, unparseable
  /// STAC response) still throw and are never cached, so the caller falls
  /// through to the next resolver tier and retries on the next visit.
  ///
  /// [sharedZipBytes] memoizes the downloaded (not parsed) asset bytes by
  /// href across every tile in the same [fetch] call — see that method's
  /// doc — so two tile coordinates resolving to the same href (the common
  /// case: one asset per lake, not per tile) share one network round trip.
  /// [sharedCandidates] does the same one step earlier, for the STAC items
  /// metadata lookup itself — see [_findAssetCandidatesForLake]'s doc.
  /// Each tile still calls [_downloadAndParseFiltered] independently to
  /// parse just its own filename-filtered subset of entries, never a
  /// subset another tile already resolved. [_firstOverlappingCandidate]
  /// then slices out just this tile's own cells before it is cached and
  /// returned, trying every candidate STAC returned for this bbox (not
  /// just the first) in case an earlier one's declared bbox overlapped but
  /// its actual content did not — see that method's doc.
  ///
  /// [freshlyResolvedLakes], when given, records [lake]'s name the moment
  /// this call passes both cache-check early-returns below and starts
  /// doing genuinely fresh work (a real STAC/download attempt, whether it
  /// ultimately succeeds, finds a definitive gap, or throws) — [fetch]
  /// uses it to tell "this lake's shared maps may hold real data worth
  /// reusing" apart from "every tile was already cached," so
  /// [_precacheSiblingSites] only ever runs when there is something to
  /// actually reuse (Copilot review: a 100%-cache-hit fetch() call used to
  /// still fire a full known-site-locations lookup for nothing).
  Future<BathymetryGrid?> _fetchTile(
    int tileE,
    int tileN,
    SwissLakeLevel lake,
    Map<String, Future<Uint8List>> sharedZipBytes,
    Map<String, Future<List<SwissBathyAsset>>> sharedCandidates, {
    Set<String>? freshlyResolvedLakes,
  }) async {
    final tileKey = '${tileE}_$tileN';

    final cached = await _tileCache.read(
      tileKey,
      expectedReferenceLevelMeters: lake.meanLevelMeters,
    );
    if (cached != null) {
      if (!_isStale(cached.checkedAt)) return cached.grid;
      return _refreshIfStale(this, tileKey, tileE, tileN, lake, cached);
    }
    if (await _tileCache.hasCachedAnswer(tileKey)) return null;

    freshlyResolvedLakes?.add(lake.name);
    final List<SwissBathyAsset> candidates;
    final ({SwissBathyAsset asset, RawEsriGrid subRaw})? resolved;
    try {
      candidates = await _findAssetCandidatesForLake(
        this,
        lake,
        sharedCandidates,
      );
      resolved = await _firstOverlappingCandidate(
        tileE,
        tileN,
        candidates,
        (href) =>
            _downloadAndParseFiltered(this, href, tileE, tileN, sharedZipBytes),
      );
    } on SwissStacException catch (e) {
      // Transient: network error, HTTP failure, unparseable STAC response.
      // Must not be cached — the next visit should retry.
      throw BathymetryFetchException('swissBATHY3D fetch failed: $e');
    } on FormatException catch (e) {
      throw BathymetryFetchException('swissBATHY3D grid parse failed: $e');
    }

    if (resolved == null) {
      // Either no candidate at all, or none of them actually cover this
      // tile once their real content was checked — deterministic for this
      // tile, so caching it avoids repeating the same lookup (and any
      // shared-href downloads) on every future visit to this coordinate.
      await _tileCache.writeEmpty(
        tileKey,
        referenceLevelMeters: lake.meanLevelMeters,
      );
      return null;
    }

    final grid = parseSwissLv95RawGrid(
      resolved.subRaw,
      sourceId: sourceId,
      fetchedAt: DateTime.now(),
      referenceLevelMeters: lake.meanLevelMeters,
    );
    await _tileCache.writeOk(
      tileKey,
      grid,
      sourceDatetime: resolved.asset.datetime,
      sourceHref: resolved.asset.href,
      referenceLevelMeters: lake.meanLevelMeters,
    );
    return grid;
  }

  /// Immediately revalidates every currently cached tile's freshness. See
  /// `swissbathy3d_freshness.dart`'s `_refreshAllCachedTilesImpl` for the
  /// full implementation, extracted there (with the rest of the periodic/
  /// manual freshness-check logic) purely for file size.
  Future<SwissBathyRefreshSummary> refreshAllCachedTiles() =>
      _refreshAllCachedTilesImpl(this);
}

/// Runs [task] over [items] with at most [maxConcurrent] running at once —
/// a small work-stealing pool, not a fixed batch-of-N-then-wait loop, so a
/// worker that finishes an early, cache-hit item immediately picks up the
/// next one instead of sitting idle until the slowest item in its batch
/// completes. Each result keeps its input's position in the returned list.
/// [task] is expected to handle its own errors (as every caller in this
/// file does): one item failing must never affect any other item's
/// in-flight or still-pending work.
Future<List<T>> _runBounded<S, T>(
  List<S> items,
  int maxConcurrent,
  Future<T> Function(S item) task,
) async {
  final results = List<T?>.filled(items.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      if (index >= items.length) return;
      nextIndex++;
      results[index] = await task(items[index]);
    }
  }

  final workerCount = maxConcurrent < items.length
      ? maxConcurrent
      : items.length;
  await Future.wait(List.generate(workerCount, (_) => worker()));
  return results.cast<T>();
}
