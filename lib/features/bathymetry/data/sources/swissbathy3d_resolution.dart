part of 'swissbathy3d_source.dart';

/// Tries each of [candidates] in order — downloading (via [download]) and
/// slicing out ([tileE], [tileN])'s own cells with
/// [extractRawEsriSubgridFromGrids] — and returns the first whose actual
/// content genuinely overlaps the tile, or null when none do.
///
/// A STAC item's declared `bbox` overlapping the query
/// ([SwissStacClient.findAssetCandidates]'s filter) is only the server's
/// word for it; it can be coarser or simply wrong relative to its own
/// raster's real footprint, which only [extractRawEsriSubgridFromGrids] —
/// reading the downloaded grid's own `xllcorner`/`yllcorner`/`ncols`/
/// `nrows` — can actually confirm. Trusting the first bbox-plausible
/// candidate alone meant one wrong-but-plausible candidate silently
/// starved every tile query it happened to satisfy, surfacing as
/// widespread "no tile here" gaps despite genuine coverage.
///
/// Before downloading anything, a candidate whose OWN [SwissBathyAsset.bbox]
/// is present but does not reach this specific tile's bounds (with a small
/// buffer, see [_tileBboxWgs84]) is skipped without a network call (GitHub
/// Copilot review): [_findAssetCandidatesForLake] now queries per LAKE, not
/// per tile (#1764), so [candidates] can include a genuinely different,
/// merely-neighboring lake's asset whose own declared bbox never actually
/// reaches every tile of the lake the query was for. This is still only a
/// pre-filter, never the correctness authority — a candidate with no
/// [SwissBathyAsset.bbox] at all is never skipped by it (same
/// unrecognized-proves-nothing rule as everywhere else in this class), and
/// [extractRawEsriSubgridFromGrids] still makes the real decision on
/// whatever content this loop does download.
Future<({SwissBathyAsset asset, RawEsriGrid subRaw})?>
_firstOverlappingCandidate(
  int tileE,
  int tileN,
  List<SwissBathyAsset> candidates,
  Future<List<RawEsriGrid>> Function(String href) download,
) async {
  final tileBbox = _tileBboxWgs84(tileE, tileN);
  for (final asset in candidates) {
    final assetBbox = asset.bbox;
    if (assetBbox != null && !_bboxesOverlap(assetBbox, tileBbox)) continue;
    final rawGrids = await download(asset.href);
    if (rawGrids.isEmpty) continue;
    final subRaw = extractRawEsriSubgridFromGrids(
      rawGrids,
      minEasting: tileE * SwissBathy3dSource.tileSizeMeters,
      maxEasting: (tileE + 1) * SwissBathy3dSource.tileSizeMeters,
      minNorthing: tileN * SwissBathy3dSource.tileSizeMeters,
      maxNorthing: (tileN + 1) * SwissBathy3dSource.tileSizeMeters,
    );
    if (subRaw == null) continue;
    return (asset: asset, subRaw: subRaw);
  }
  return null;
}

/// Tile ([tileE], [tileN])'s own bounds, reprojected to WGS84 and padded
/// by the same small epsilon [_findAssetCandidatesForLake] already uses
/// for the lake-level query — this is a cheap pre-filter, not the
/// correctness authority (see [_firstOverlappingCandidate]'s own doc), so
/// a slightly generous box only risks trying one extra candidate, never
/// wrongly skipping a real one.
({double minLon, double minLat, double maxLon, double maxLat}) _tileBboxWgs84(
  int tileE,
  int tileN,
) {
  const epsilon = 0.0005;
  final corners = [
    Lv95Transform.toWgs84(
      tileE * SwissBathy3dSource.tileSizeMeters,
      tileN * SwissBathy3dSource.tileSizeMeters,
    ),
    Lv95Transform.toWgs84(
      (tileE + 1) * SwissBathy3dSource.tileSizeMeters,
      tileN * SwissBathy3dSource.tileSizeMeters,
    ),
    Lv95Transform.toWgs84(
      tileE * SwissBathy3dSource.tileSizeMeters,
      (tileN + 1) * SwissBathy3dSource.tileSizeMeters,
    ),
    Lv95Transform.toWgs84(
      (tileE + 1) * SwissBathy3dSource.tileSizeMeters,
      (tileN + 1) * SwissBathy3dSource.tileSizeMeters,
    ),
  ];
  var minLon = double.infinity;
  var minLat = double.infinity;
  var maxLon = -double.infinity;
  var maxLat = -double.infinity;
  for (final corner in corners) {
    if (corner.longitude < minLon) minLon = corner.longitude;
    if (corner.longitude > maxLon) maxLon = corner.longitude;
    if (corner.latitude < minLat) minLat = corner.latitude;
    if (corner.latitude > maxLat) maxLat = corner.latitude;
  }
  return (
    minLon: minLon - epsilon,
    minLat: minLat - epsilon,
    maxLon: maxLon + epsilon,
    maxLat: maxLat + epsilon,
  );
}

bool _bboxesOverlap(
  ({double minLon, double minLat, double maxLon, double maxLat}) a,
  ({double minLon, double minLat, double maxLon, double maxLat}) b,
) {
  return a.minLon <= b.maxLon &&
      a.maxLon >= b.minLon &&
      a.minLat <= b.maxLat &&
      a.maxLat >= b.minLat;
}

/// Memoizes [compute] under [key] in [cache], like [Map.putIfAbsent], but
/// evicts a REJECTED future once it fails instead of leaving it cached.
///
/// A plain `putIfAbsent(key, compute)` stores whatever future `compute()`
/// returns immediately, including one that later fails: every other caller
/// sharing this [cache] within the same `fetch()`/`refreshAllCachedTiles()`
/// call then awaits that same rejected future and fails too, even though a
/// fresh attempt might well have succeeded. That turns one transient
/// network blip into a whole-lake failure — reintroducing #1764's own
/// amplification pattern in the failure direction this time, most visibly
/// in `refreshAllCachedTiles()`'s sweep, which tallies each cached tile
/// independently and would otherwise mark every stale tile of the affected
/// lake as failed for what was really only one bad request (Copilot
/// review). Concurrent callers before the failure resolves still share the
/// one in-flight attempt exactly as `putIfAbsent` would; only a caller
/// arriving AFTER it has already failed gets a fresh retry.
Future<T> _memoizeFuture<T>(
  Map<String, Future<T>> cache,
  String key,
  Future<T> Function() compute,
) {
  final existing = cache[key];
  if (existing != null) return existing;
  late Future<T> future;
  future = () async {
    try {
      return await compute();
    } catch (_) {
      if (identical(cache[key], future)) cache.remove(key);
      rethrow;
    }
  }();
  cache[key] = future;
  return future;
}

/// Downloads the zip at [href], memoized in [shared]'s `zipBytes` by href
/// so a shared lake-wide asset travels over the network only once per
/// `fetch()`/`refreshAllCachedTiles()` call regardless of how many tiles
/// resolve to it — see those methods' docs.
Future<Uint8List> _downloadZipBytes(
  SwissBathy3dSource source,
  String href,
  _SharedFetchState shared,
) => _memoizeFuture(
  shared.zipBytes,
  href,
  () => source._stac.downloadBytes(href),
);

/// Parses (and memoizes, see [_memoizeFuture]) zip entry [entry]'s own
/// grid, keyed by `'$href#${entry.name}'` in [parsedEntries] -- shared not
/// just across concurrent callers of the SAME tile (like
/// [_downloadZipBytes] already does for the raw bytes) but across every
/// DIFFERENT tile that also happens to need this same entry AND shares
/// this same [parsedEntries] map, which two neighboring tiles'
/// [_entryTileRe]-based "within one tile" windows routinely overlap on.
/// See `swissbathy3d_source.dart`'s own class doc for why sharing this
/// parsed-entry WORK is safe even though sharing which entries a tile
/// even considers (Bug 15) is not, and [_fetchTile]'s doc for why
/// [parsedEntries] is passed as its own parameter rather than living on
/// [_SharedFetchState] -- callers deliberately vary its actual sharing
/// scope.
Future<RawEsriGrid> _parsedEntry(
  String href,
  ArchiveFile entry,
  Map<String, Future<RawEsriGrid>> parsedEntries,
) => _memoizeFuture(parsedEntries, '$href#${entry.name}', () async {
  final text = utf8.decode(entry.readBytes() ?? const [], allowMalformed: true);
  return EsriAsciiGridParser.parseRaw(text);
});

/// Matches swisstopo's internal entry naming, e.g.
/// `swissBATHY3D_CHLV95_LN02_2726_1221.asc` — confirmed, across every lake
/// in [swissLakeLevels] plus several published outside it, to encode that
/// entry's own `xllcorner`/`yllcorner` truncated to the kilometre (e.g.
/// xllcorner 2726016 for `..._2726_1221.asc`).
final RegExp _entryTileRe = RegExp(
  r'_(\d{3,4})_(\d{3,4})\.(asc|grd)$',
  caseSensitive: false,
);

/// The `.asc`/`.grd` entries of [archive] relevant to tile ([tileE],
/// [tileN]), in the archive's own order, or empty when it contains none.
///
/// Considering every entry regardless of relevance was correct (see Bug 15
/// below) but expensive: some lakes' zips hold hundreds of entries and
/// hundreds of MB uncompressed, all to answer one 1-km tile's query. Only
/// entries whose filename (see [_entryTileRe]) declares a tile within one
/// tile of ([tileE], [tileN]) in every direction are kept — generous
/// headroom over the tens-of-metres misalignment a live check found
/// between a raster's real `xllcorner` and its filename's kilometre
/// label. An entry whose name does not match [_entryTileRe] at all is
/// still always included: an unrecognized name proves nothing about
/// location, and excluding it would risk resurrecting Bug 15 for that
/// entry. If swisstopo ever changes its naming scheme, every entry falls
/// back to this always-included path and this function's cost degrades
/// to exactly what considering every entry unconditionally always cost —
/// slower, never wrong.
///
/// The caller (`_firstOverlappingCandidate`, via
/// [extractRawEsriSubgridFromGrids]) still re-checks every returned
/// entry's OWN real `xllcorner`/`yllcorner`/`ncols`/`nrows` against the
/// requested tile before accepting it — this prefilter only decides what
/// gets decompressed and parsed at all, never what counts as a match. That
/// is also why a zip whose entries do not follow the one-per-lake
/// assumption (Bug 15: swisstopo's own internal sub-tiling can itself be
/// smaller than 1 km) still resolves correctly: the surviving entries
/// after this prefilter are searched exactly the same way the whole set
/// used to be.
Iterable<ArchiveFile> _entriesNearTile(
  Archive archive, {
  required int tileE,
  required int tileN,
}) {
  return archive.where((entry) {
    if (!entry.isFile) return false;
    final lower = entry.name.toLowerCase();
    if (!lower.endsWith('.asc') && !lower.endsWith('.grd')) return false;
    final match = _entryTileRe.firstMatch(entry.name);
    if (match == null) return true;
    final entryE = int.parse(match.group(1)!);
    final entryN = int.parse(match.group(2)!);
    return (entryE - tileE).abs() <= 1 && (entryN - tileN).abs() <= 1;
  });
}

/// Downloads (shared, see [_downloadZipBytes]) and parses only the entries
/// of the zip at [href] relevant to tile ([tileE], [tileN]) — potentially
/// several, each an entire lake's worth of cells, or swisstopo's own
/// internal sub-tiles of one, see [extractRawEsriSubgridFromGrids]'s doc —
/// never the whole zip regardless of how many entries it holds. See
/// [_entriesNearTile]'s doc for the filename-based prefilter and its
/// always-safe fallback, and [_parsedEntry]'s doc for why the actual
/// decompress-and-parse step per entry IS shared across tiles, unlike
/// that prefilter decision itself.
///
/// `ZipDecoder().decodeBytes` throws its own `ArchiveException` (not
/// [FormatException]) on malformed zip bytes — e.g. an HTTP 200 response
/// body that is actually an HTML error page, or a truncated download.
/// Every callsite of this method already narrows on [FormatException] to
/// report a clean parse failure rather than a transient one, so anything
/// the decode or grid parse step throws that is not already a
/// [FormatException] is normalized into one here, instead of escaping as a
/// raw `ArchiveException` (or any other type) and crashing the fetch/stitch
/// pipeline.
Future<List<RawEsriGrid>> _downloadAndParseFiltered(
  SwissBathy3dSource source,
  String href,
  int tileE,
  int tileN,
  _SharedFetchState shared,
  Map<String, Future<RawEsriGrid>> parsedEntries,
) async {
  final zipBytes = await _downloadZipBytes(source, href, shared);
  try {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final grids = <RawEsriGrid>[];
    for (final entry in _entriesNearTile(archive, tileE: tileE, tileN: tileN)) {
      grids.add(await _parsedEntry(href, entry, parsedEntries));
    }
    return grids;
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('swissBATHY3D zip/grid decode failed: $e');
  }
}

/// The [SwissBathyAsset] candidates covering [lake], memoized in
/// [shared]'s `candidates` by lake name across every tile of one `fetch()`/
/// `refreshAllCachedTiles()` call — the STAC items lookup this wraps is
/// queried against [lake]'s own (generous, per [SwissLakeLevel]'s doc)
/// bounding box instead of one tile's tiny ~1 km box, so it is safe to
/// share: any item overlapping a tile's own small box necessarily also
/// overlaps the box of the lake that tile resolved into, so a lake-wide
/// query never misses a candidate a per-tile query would have found (and
/// can only surface MORE, e.g. a genuinely overlapping neighbor lake at a
/// shared boundary — [_firstOverlappingCandidate] still validates every
/// candidate's actual downloaded content against each tile's own real
/// extent regardless, so a broader candidate list here cannot make a wrong
/// candidate win).
///
/// Before this, swisstopo publishing one asset per LAKE (not per tile —
/// see `swissbathy3d_source.dart`'s own class doc) meant an 8 km span
/// touching up to 81 tiles fired up to 81 near-identical metadata lookups
/// for an answer that never varies within a lake: needless load on the OGD
/// API, and up to 81 separate 15 s-budgeted chances for a single slow or
/// transiently failed lookup to fail the entire span (#1764). Memoizing via
/// [_memoizeFuture], exactly like `sharedZipBytes` does for the asset
/// download, means concurrently-dispatched tiles of the same lake share
/// one in-flight request instead of each starting their own, while a
/// FAILED attempt is evicted rather than replayed to every other tile of
/// the lake in this call (see [_memoizeFuture]'s own doc).
///
/// Queried with the same small epsilon buffer the old per-tile bbox used
/// to carry (Copilot review): several registered lake boxes in
/// [swissLakeLevels] are deliberately hand-tightened to just inside the
/// real STAC item's own edge, specifically to stop them overlapping a
/// neighboring lake for point-containment ([findSwissLake]). Querying that
/// tightened box with zero margin would silently return no candidates at
/// all if swisstopo ever republishes an item whose bbox contracts by even
/// a fraction of a degree at that edge; the buffer costs nothing here
/// (unlike the removed per-tile one, this query already runs at most once
/// per lake per call) and keeps that failure mode firmly theoretical.
Future<List<SwissBathyAsset>> _findAssetCandidatesForLake(
  SwissBathy3dSource source,
  SwissLakeLevel lake,
  _SharedFetchState shared,
) => _memoizeFuture(shared.candidates, lake.name, () {
  const epsilon = 0.0005;
  return _findAssetCandidates(source, [
    lake.minLon - epsilon,
    lake.minLat - epsilon,
    lake.maxLon + epsilon,
    lake.maxLat + epsilon,
  ]);
});

/// Tries each candidate collection ID in turn, falling through to the next
/// on a confirmed 404 (wrong ID) rather than failing outright.
Future<List<SwissBathyAsset>> _findAssetCandidates(
  SwissBathy3dSource source,
  List<double> bbox,
) async {
  SwissStacCollectionNotFoundException? lastNotFound;
  for (final collectionId in SwissStacClient.collectionIds) {
    try {
      return await source._stac.findAssetCandidates(
        collectionId: collectionId,
        bbox: bbox,
      );
    } on SwissStacCollectionNotFoundException catch (e) {
      lastNotFound = e;
    }
  }
  throw BathymetryFetchException(
    'no known swissBATHY3D collection id resolved: $lastNotFound',
  );
}

GeoPoint _tileCenterWgs84(int tileE, int tileN) {
  final center = Lv95Transform.toWgs84(
    (tileE + 0.5) * SwissBathy3dSource.tileSizeMeters,
    (tileN + 0.5) * SwissBathy3dSource.tileSizeMeters,
  );
  return GeoPoint(center.latitude, center.longitude);
}

/// Merges same-resolution tile grids into one rectangular [BathymetryGrid]
/// spanning all of them. Each tile's cells are placed by rounding its
/// origin's offset from the merged origin to the nearest cell — robust to
/// the sub-cell drift between tiles' independently-reprojected LV95
/// origins (see [parseSwissLv95Grid]) — rather than assuming tiles are
/// pixel-perfectly aligned. Gaps (no tile, or nodata cells) stay null.
BathymetryGrid _stitchTiles(List<BathymetryGrid> tiles) {
  final reference = tiles.first;
  final cellSizeLat = reference.cellSizeLatDeg;
  final cellSizeLon = reference.cellSizeLonDeg;

  var minLat = double.infinity;
  var maxLat = -double.infinity;
  var minLon = double.infinity;
  var maxLon = -double.infinity;
  for (final tile in tiles) {
    final tileMinLat = tile.originLat - cellSizeLat / 2;
    final tileMaxLat = tile.originLat + cellSizeLat * (tile.rows - 0.5);
    final tileMinLon = tile.originLon - cellSizeLon / 2;
    final tileMaxLon = tile.originLon + cellSizeLon * (tile.cols - 0.5);
    if (tileMinLat < minLat) minLat = tileMinLat;
    if (tileMaxLat > maxLat) maxLat = tileMaxLat;
    if (tileMinLon < minLon) minLon = tileMinLon;
    if (tileMaxLon > maxLon) maxLon = tileMaxLon;
  }

  final rows = ((maxLat - minLat) / cellSizeLat).round();
  final cols = ((maxLon - minLon) / cellSizeLon).round();
  final originLat = minLat + cellSizeLat / 2;
  final originLon = minLon + cellSizeLon / 2;

  final merged = List<double?>.filled(rows * cols, null);
  var fetchedAt = reference.fetchedAt;
  for (final tile in tiles) {
    if (tile.fetchedAt.isBefore(fetchedAt)) fetchedAt = tile.fetchedAt;
    final rowOffset = ((tile.originLat - originLat) / cellSizeLat).round();
    final colOffset = ((tile.originLon - originLon) / cellSizeLon).round();
    for (var r = 0; r < tile.rows; r++) {
      final mergedRow = rowOffset + r;
      if (mergedRow < 0 || mergedRow >= rows) continue;
      for (var c = 0; c < tile.cols; c++) {
        final mergedCol = colOffset + c;
        if (mergedCol < 0 || mergedCol >= cols) continue;
        final depth = tile.depthAt(r, c);
        if (depth != null) merged[mergedRow * cols + mergedCol] = depth;
      }
    }
  }

  return BathymetryGrid(
    originLat: originLat,
    originLon: originLon,
    cellSizeLatDeg: cellSizeLat,
    cellSizeLonDeg: cellSizeLon,
    rows: rows,
    cols: cols,
    depthsMeters: merged,
    sourceId: reference.sourceId,
    resolutionMeters: reference.resolutionMeters,
    fetchedAt: fetchedAt,
  );
}
