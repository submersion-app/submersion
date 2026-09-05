// Debug-only diagnostics for swissBATHY3D integration. Gated behind
// kDebugMode; not present in release builds.
//
// Investigated the suspected root cause behind Bug 6/7/9 (two real,
// independently-meaningful dive sites at Walensee reportedly render a
// pixel-identical 3D mesh): [BathymetryRepository] used to share one cached
// grid across every coordinate inside its 0.02 degree quantized cell
// (roughly 2.2 km x 1.5 km at Swiss latitudes — wider than some lakes), so
// two sites closer together than that received the exact same fetch by
// design. Bug 10 made that quantization source-specific (see
// [BathymetryRepository.quantumDegFor]): inside a swissBATHY3D lake the raw
// coordinate is used as-is instead. This module recomputes, read-only and
// without any network call, the same coordinate/cache-key derivation the
// production pipeline performs, so that derivation is visible in the
// running app without a debugger.
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/windows_app_data_migration.dart'
    show legacyWindowsCompanyName, windowsProductName;
import 'package:submersion/core/utils/lv95_transform.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/esri_ascii_parser.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lake_levels.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lv95_grid.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_stac_client.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One swissBATHY3D tile's cache status, for [SwissBathyDebugInfo.tiles].
class SwissBathyTileDebugInfo {
  final String tileKey;
  final bool cached;
  final DateTime? checkedAt;

  /// The key [SwissBathyTileCacheRepository] actually used to look this tile
  /// up (its `read`/`writeOk` argument). Always equal to [tileKey] today —
  /// the repository has no separate transformation step between the two —
  /// but shown explicitly, not assumed, since a mismatch here would be a
  /// direct explanation for two different tile ranges resolving to the same
  /// cached content.
  final String lookupKey;

  /// A fingerprint of THIS tile's own raw, individually-cached grid (before
  /// [SwissBathy3dSource._stitchTiles] merges it with any neighbor), or null
  /// when [cached] is false. Reuses [SwissBathyGridFingerprint] — the same
  /// hash this module already applies to the post-stitch grid — one layer
  /// further upstream: if two DIFFERENT tile keys (different physical 1-km
  /// squares) carry the SAME [rawFingerprint], the corruption is already in
  /// the tile cache itself, not introduced by stitching.
  final SwissBathyGridFingerprint? rawFingerprint;

  const SwissBathyTileDebugInfo({
    required this.tileKey,
    required this.cached,
    this.checkedAt,
    required this.lookupKey,
    this.rawFingerprint,
  });
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR.
class SwissBathyDebugInfo {
  final String siteId;
  final String siteName;
  final GeoPoint siteCoordinate;

  /// The cell [BathymetryRepository.quantize] derives from [siteCoordinate]
  /// — the outer grid cache's actual sharing granularity. Equals
  /// [siteCoordinate] itself when [quantumDeg] is 0 (no coalescing).
  final ({double lat, double lon}) quantizedCell;

  /// The cache granularity actually applied to [siteCoordinate], per
  /// [BathymetryRepository.quantumDegFor]: 0 means no quantization (inside
  /// a swissBATHY3D lake), otherwise the standard 0.02 degree cell.
  final double quantumDeg;

  /// [BathymetryRepository.keyFor]'s cache key for [siteCoordinate]. Two
  /// sites with an identical value here share one cached [BathymetryGrid]
  /// row, byte for byte.
  final String outerCacheKey;

  /// The quantized cell's center — what the repository actually fetches
  /// around, per coordinate in the cell, not [siteCoordinate] itself.
  final GeoPoint fetchCenter;

  final bool insideSwissLakeCoverage;

  /// [fetchCenter] reprojected to LV95, or null outside lake coverage.
  final Lv95Coordinates? lv95;

  /// Every 1-km swissBATHY3D tile [SwissBathy3dSource.fetch] would request
  /// for [fetchCenter] at the resolver's default span, and whether each is
  /// already cached.
  final List<SwissBathyTileDebugInfo> tiles;

  /// The STAC items query URL for the first tile in [tiles], for a human to
  /// paste into a browser — built the same way [SwissStacClient.findAsset]
  /// builds it, without making the request.
  final String? firstTileStacUrl;

  /// The real header/row-col extraction diagnostic for the first tile in
  /// [tiles] (Bug 14) — unlike everything else in this class, building this
  /// DOES make network calls (see [buildSwissBathyExtractionDebugInfo]).
  /// Null only when [insideSwissLakeCoverage] is false (no tile to diagnose).
  final SwissBathyExtractionDebugInfo? firstTileExtraction;

  /// Where the swissBATHY3D-related caches actually live on disk, and which
  /// path_provider call resolved that location — independent of
  /// [insideSwissLakeCoverage] (a storage-location question, not a
  /// this-site-specific one).
  final SwissBathyCachePathsDebugInfo cachePaths;

  const SwissBathyDebugInfo({
    required this.siteId,
    required this.siteName,
    required this.siteCoordinate,
    required this.quantizedCell,
    required this.quantumDeg,
    required this.outerCacheKey,
    required this.fetchCenter,
    required this.insideSwissLakeCoverage,
    required this.lv95,
    required this.tiles,
    required this.firstTileStacUrl,
    required this.firstTileExtraction,
    required this.cachePaths,
  });
}

/// Builds a [SwissBathyDebugInfo] snapshot for [siteId]/[center]. Read-only:
/// issues no network requests and writes no cache rows, only re-derives
/// values and reads existing tile-cache rows (when the local cache database
/// is available; tile cache status is omitted otherwise).
Future<SwissBathyDebugInfo> buildSwissBathyDebugInfo({
  required String siteId,
  required String siteName,
  required GeoPoint center,
}) async {
  final quantum = BathymetryRepository.quantumDegFor(center);
  final cell = BathymetryRepository.quantize(center);
  final outerKey = BathymetryRepository.keyFor(center);
  final fetchCenter = quantum > 0
      ? GeoPoint(cell.lat + quantum / 2, cell.lon + quantum / 2)
      : center;
  final cachePaths = await buildSwissBathyCachePathsDebugInfo();

  final lake = findSwissLake(fetchCenter);
  if (lake == null) {
    return SwissBathyDebugInfo(
      siteId: siteId,
      siteName: siteName,
      siteCoordinate: center,
      quantizedCell: cell,
      quantumDeg: quantum,
      outerCacheKey: outerKey,
      fetchCenter: fetchCenter,
      insideSwissLakeCoverage: false,
      lv95: null,
      tiles: const [],
      firstTileStacUrl: null,
      firstTileExtraction: null,
      cachePaths: cachePaths,
    );
  }

  final lv95 = Lv95Transform.fromWgs84(
    fetchCenter.latitude,
    fetchCenter.longitude,
  );
  const spanMeters = BathymetryResolver.defaultSpanMeters;
  const tileSize = SwissBathy3dSource.tileSizeMeters;
  const half = spanMeters / 2;
  final tileEMin = ((lv95.easting - half) / tileSize).floor();
  final tileEMax = ((lv95.easting + half) / tileSize).floor();
  final tileNMin = ((lv95.northing - half) / tileSize).floor();
  final tileNMax = ((lv95.northing + half) / tileSize).floor();

  LocalCacheDatabase? db;
  try {
    db = LocalCacheDatabaseService.instance.database;
  } on StateError {
    db = null;
  }
  final tileCache = db == null ? null : SwissBathyTileCacheRepository(db);

  final tiles = <SwissBathyTileDebugInfo>[];
  for (var n = tileNMin; n <= tileNMax; n++) {
    for (var e = tileEMin; e <= tileEMax; e++) {
      final tileKey = '${e}_$n';
      var cached = false;
      DateTime? checkedAt;
      SwissBathyGridFingerprint? rawFingerprint;
      if (tileCache != null) {
        // Same read-only lookup SwissBathy3dSource._fetchTile performs
        // before ever stitching this tile into a larger grid — the
        // repository's read/write argument IS the tile key itself (no
        // separate key derivation to diverge from it), so lookupKey below
        // is always tileKey, shown explicitly rather than assumed.
        final entry = await tileCache.read(tileKey);
        cached = entry != null;
        checkedAt = entry?.checkedAt;
        if (entry != null) {
          rawFingerprint = buildSwissBathyGridFingerprint(entry.grid);
        }
      }
      tiles.add(
        SwissBathyTileDebugInfo(
          tileKey: tileKey,
          cached: cached,
          checkedAt: checkedAt,
          lookupKey: tileKey,
          rawFingerprint: rawFingerprint,
        ),
      );
    }
  }

  final bbox = _tileBboxWgs84(tileEMin, tileNMin);
  final firstUrl =
      Uri.parse(
            'https://data.geo.admin.ch/api/stac/v1/collections/'
            '${SwissStacClient.collectionIds.first}/items',
          )
          .replace(
            queryParameters: {
              'bbox': bbox.map((v) => v.toString()).join(','),
              'limit': '10',
            },
          )
          .toString();

  final firstTileExtraction = await buildSwissBathyExtractionDebugInfo(
    tileE: tileEMin,
    tileN: tileNMin,
  );

  return SwissBathyDebugInfo(
    siteId: siteId,
    siteName: siteName,
    siteCoordinate: center,
    quantizedCell: cell,
    quantumDeg: quantum,
    outerCacheKey: outerKey,
    fetchCenter: fetchCenter,
    insideSwissLakeCoverage: true,
    lv95: lv95,
    tiles: tiles,
    firstTileStacUrl: firstUrl,
    firstTileExtraction: firstTileExtraction,
    cachePaths: cachePaths,
  );
}

/// Mirrors [SwissBathy3dSource._tileBboxWgs84] (private there) so the URL
/// shown here matches exactly what a real fetch would query.
List<double> _tileBboxWgs84(int tileE, int tileN) {
  final sw = Lv95Transform.toWgs84(
    tileE * SwissBathy3dSource.tileSizeMeters,
    tileN * SwissBathy3dSource.tileSizeMeters,
  );
  final ne = Lv95Transform.toWgs84(
    (tileE + 1) * SwissBathy3dSource.tileSizeMeters,
    (tileN + 1) * SwissBathy3dSource.tileSizeMeters,
  );
  const epsilon = 0.0005;
  return [
    sw.longitude - epsilon,
    sw.latitude - epsilon,
    ne.longitude + epsilon,
    ne.latitude + epsilon,
  ];
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR.
///
/// Investigated Bug 14 (extractRawEsriSubgrid() reportedly returning null
/// for nearly every tile in a lake, or — for the one tile that did cache —
/// a hash identical to the whole, unclipped lake grid from before that
/// function existed): earlier bug reports about this extraction step were
/// diagnosed by re-deriving its row/col arithmetic on paper, never against
/// the actual downloaded file. This class instead carries the REAL header
/// values and the REAL row/col window [extractRawEsriSubgrid] computes for
/// one concrete tile, straight off a genuine STAC lookup and asset
/// download — no theory, just the numbers the extraction step itself would
/// see and act on.
class SwissBathyExtractionDebugInfo {
  final String tileKey;

  /// The STAC asset actually resolved for this tile's bbox, or null when
  /// the lookup itself failed or found nothing (see [error]).
  final String? assetHref;

  /// Set when the STAC lookup, download, or grid parse failed before a
  /// header could even be read — every field below is null in that case.
  final String? error;

  /// How many `.asc`/`.grd` entries the downloaded zip actually contained
  /// (see [extractGridZipTexts]) — null only on [error]. Bug 15: this was
  /// silently assumed to always be 1; a value greater than 1 here, on a
  /// lake whose earlier live tests showed only one tile ever cached, is
  /// itself the direct confirmation of that bug's root cause.
  final int? entryCount;

  /// Which of the zip's [entryCount] entries actually overlapped this
  /// tile's bbox once [extractRawEsriSubgrid] checked its real header
  /// (0-based), or null when none did. The header fields below describe
  /// this entry when set, or the zip's first entry otherwise (for
  /// visibility into what a "no overlap" verdict was actually checked
  /// against).
  final int? matchedEntryIndex;

  /// The inspected entry's own ESRI ASCII header (`ncols`/`nrows`/
  /// `xllcorner`/`yllcorner`/`cellsize`), exactly as
  /// [EsriAsciiGridParser.parseRaw] read it — null only on [error] or an
  /// empty zip.
  final int? ncols;
  final int? nrows;
  final double? xllcorner;
  final double? yllcorner;
  final double? cellsize;

  /// This tile's target bounding box in LV95 meters — the same
  /// min/maxEasting/Northing values
  /// [SwissBathy3dSource._firstOverlappingCandidate] passes to
  /// [extractRawEsriSubgrid] for this tile. Always known (no network call
  /// needed), unlike everything below it.
  final double minEasting;
  final double maxEasting;
  final double minNorthing;
  final double maxNorthing;

  /// The row/col window [extractRawEsriSubgrid] derives from the header
  /// and bbox above, BEFORE its own `clampInt(...,0,nrows/ncols)` call —
  /// null on [error]. A negative or past-the-edge value here (rather than
  /// a silently clamped one) is the arithmetic actually going wrong, not a
  /// tile that is genuinely just outside the downloaded grid.
  final int? colFromRaw;
  final int? colToRaw;
  final int? rowFromRaw;
  final int? rowToRaw;

  /// The same window after [extractRawEsriSubgrid]'s own clamp — what it
  /// actually slices with. `colFromClamped >= colToClamped` (or the row
  /// equivalent) is exactly the condition under which it returns null.
  final int? colFromClamped;
  final int? colToClamped;
  final int? rowFromClamped;
  final int? rowToClamped;

  /// Whether [extractRawEsriSubgrid], called with these exact inputs,
  /// actually returned a non-null slice — the ground truth this whole
  /// diagnostic exists to explain.
  final bool extractionSucceeded;

  const SwissBathyExtractionDebugInfo({
    required this.tileKey,
    required this.assetHref,
    required this.error,
    required this.entryCount,
    required this.matchedEntryIndex,
    required this.ncols,
    required this.nrows,
    required this.xllcorner,
    required this.yllcorner,
    required this.cellsize,
    required this.minEasting,
    required this.maxEasting,
    required this.minNorthing,
    required this.maxNorthing,
    required this.colFromRaw,
    required this.colToRaw,
    required this.rowFromRaw,
    required this.rowToRaw,
    required this.colFromClamped,
    required this.colToClamped,
    required this.rowFromClamped,
    required this.rowToClamped,
    required this.extractionSucceeded,
  });
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Builds a
/// [SwissBathyExtractionDebugInfo] for tile ([tileE], [tileN]) by actually
/// performing the STAC items lookup and downloading+parsing the first
/// resolved candidate — the same steps
/// [SwissBathy3dSource._firstOverlappingCandidate] takes for a real fetch —
/// so the header and row/col numbers below come from the real file, not a
/// second paper recalculation. Unlike the rest of this module, this DOES
/// issue network requests; scoped to one tile, only run when the debug
/// panel is expanded (see `site_terrain_pane.dart`).
Future<SwissBathyExtractionDebugInfo> buildSwissBathyExtractionDebugInfo({
  required int tileE,
  required int tileN,
  http.Client? httpClient,
}) async {
  final tileKey = '${tileE}_$tileN';
  final minEasting = tileE * SwissBathy3dSource.tileSizeMeters;
  final maxEasting = (tileE + 1) * SwissBathy3dSource.tileSizeMeters;
  final minNorthing = tileN * SwissBathy3dSource.tileSizeMeters;
  final maxNorthing = (tileN + 1) * SwissBathy3dSource.tileSizeMeters;

  SwissBathyExtractionDebugInfo failure(String error, {String? assetHref}) =>
      SwissBathyExtractionDebugInfo(
        tileKey: tileKey,
        assetHref: assetHref,
        error: error,
        entryCount: null,
        matchedEntryIndex: null,
        ncols: null,
        nrows: null,
        xllcorner: null,
        yllcorner: null,
        cellsize: null,
        minEasting: minEasting,
        maxEasting: maxEasting,
        minNorthing: minNorthing,
        maxNorthing: maxNorthing,
        colFromRaw: null,
        colToRaw: null,
        rowFromRaw: null,
        rowToRaw: null,
        colFromClamped: null,
        colToClamped: null,
        rowFromClamped: null,
        rowToClamped: null,
        extractionSucceeded: false,
      );

  final stac = SwissStacClient(client: httpClient);
  final bbox = _tileBboxWgs84(tileE, tileN);

  // Mirrors SwissBathy3dSource._findAssetCandidates: try every known
  // collection id, falling through on a confirmed 404.
  List<SwissBathyAsset> candidates = const [];
  SwissStacCollectionNotFoundException? lastNotFound;
  var resolvedCollection = false;
  for (final collectionId in SwissStacClient.collectionIds) {
    try {
      candidates = await stac.findAssetCandidates(
        collectionId: collectionId,
        bbox: bbox,
      );
      resolvedCollection = true;
      break;
    } on SwissStacCollectionNotFoundException catch (e) {
      lastNotFound = e;
    } on SwissStacException catch (e) {
      return failure('STAC items lookup failed: $e');
    }
  }
  if (!resolvedCollection) {
    return failure('no known collection id resolved: $lastNotFound');
  }
  if (candidates.isEmpty) {
    return failure('no STAC candidates overlap this tile bbox');
  }

  final asset = candidates.first;
  final Uint8List zipBytes;
  try {
    zipBytes = await stac.downloadBytes(asset.href);
  } on SwissStacException catch (e) {
    return failure('asset download failed: $e', assetHref: asset.href);
  }

  final gridTexts = SwissBathy3dSource.extractGridZipTexts(zipBytes);
  if (gridTexts.isEmpty) {
    return failure('zip contains no .asc/.grd entry', assetHref: asset.href);
  }

  // Bug 15: the zip is not guaranteed to hold exactly one grid file -- try
  // every entry (mirroring extractRawEsriSubgridFromGrids), so entryCount
  // and matchedEntryIndex below show the real ground truth instead of
  // assuming entry 0 is the only one worth inspecting.
  final List<RawEsriGrid> rawGrids;
  try {
    rawGrids = [
      for (final text in gridTexts) EsriAsciiGridParser.parseRaw(text),
    ];
  } on FormatException catch (e) {
    return failure('grid parse failed: $e', assetHref: asset.href);
  }

  int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  var matchedEntryIndex = -1;
  for (var i = 0; i < rawGrids.length; i++) {
    final slice = extractRawEsriSubgrid(
      rawGrids[i],
      minEasting: minEasting,
      maxEasting: maxEasting,
      minNorthing: minNorthing,
      maxNorthing: maxNorthing,
    );
    if (slice != null) {
      matchedEntryIndex = i;
      break;
    }
  }
  // No entry actually overlapped: still report the first entry's own
  // header/window below, since that is what a "no overlap" verdict would
  // have been checked against.
  final inspectedIndex = matchedEntryIndex >= 0 ? matchedEntryIndex : 0;
  final raw = rawGrids[inspectedIndex];

  final colFromRaw = ((minEasting - raw.xll) / raw.cellsize).floor();
  final colToRaw = ((maxEasting - raw.xll) / raw.cellsize).ceil();
  final rowFromRaw = ((minNorthing - raw.yll) / raw.cellsize).floor();
  final rowToRaw = ((maxNorthing - raw.yll) / raw.cellsize).ceil();

  final extracted = matchedEntryIndex >= 0;

  return SwissBathyExtractionDebugInfo(
    tileKey: tileKey,
    assetHref: asset.href,
    error: null,
    entryCount: rawGrids.length,
    matchedEntryIndex: matchedEntryIndex >= 0 ? matchedEntryIndex : null,
    ncols: raw.ncols,
    nrows: raw.nrows,
    xllcorner: raw.xll,
    yllcorner: raw.yll,
    cellsize: raw.cellsize,
    minEasting: minEasting,
    maxEasting: maxEasting,
    minNorthing: minNorthing,
    maxNorthing: maxNorthing,
    colFromRaw: colFromRaw,
    colToRaw: colToRaw,
    rowFromRaw: rowFromRaw,
    rowToRaw: rowToRaw,
    colFromClamped: clampInt(colFromRaw, 0, raw.ncols),
    colToClamped: clampInt(colToRaw, 0, raw.ncols),
    rowFromClamped: clampInt(rowFromRaw, 0, raw.nrows),
    rowToClamped: clampInt(rowToRaw, 0, raw.nrows),
    extractionSucceeded: extracted,
  );
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Renders a
/// [SwissBathyExtractionDebugInfo] as plain, copy-pasteable text, appended
/// below [formatSwissBathyDebugInfo]'s output.
String formatSwissBathyExtractionDebugInfo(SwissBathyExtractionDebugInfo info) {
  final buf = StringBuffer()
    ..writeln(
      '--- extraction diagnostic for tile ${info.tileKey} (temporary) ---',
    );
  if (info.error != null) {
    buf.write('FAILED: ${info.error}');
    if (info.assetHref != null) buf.write(' (asset: ${info.assetHref})');
    return buf.toString();
  }
  buf
    ..writeln('asset href: ${info.assetHref}')
    ..writeln(
      'zip .asc/.grd entries: ${info.entryCount} '
      '(matched entry: ${info.matchedEntryIndex ?? "none"}) '
      '-- Bug 15: more than 1 here confirms the zip holds several internal '
      'sub-tiles, not one grid per lake',
    )
    ..writeln(
      'inspected entry grid header: ncols=${info.ncols} nrows=${info.nrows} '
      'xllcorner=${info.xllcorner} yllcorner=${info.yllcorner} '
      'cellsize=${info.cellsize}',
    )
    ..writeln(
      'target bbox (LV95 m): '
      'E[${info.minEasting}..${info.maxEasting}] '
      'N[${info.minNorthing}..${info.maxNorthing}]',
    )
    ..writeln(
      'row/col window, unclamped: '
      'col[${info.colFromRaw}..${info.colToRaw}) '
      'row[${info.rowFromRaw}..${info.rowToRaw}) '
      '(valid index range is [0,ncols)/[0,nrows) — colTo/rowTo==ncols/nrows '
      'is a normal, in-range EXCLUSIVE end, not an overflow)',
    )
    ..writeln(
      'row/col window, after clampInt(...,0,ncols/nrows): '
      'col[${info.colFromClamped}..${info.colToClamped}) '
      'row[${info.rowFromClamped}..${info.rowToClamped}) '
      '${(info.colFromClamped ?? 0) >= (info.colToClamped ?? 0) || (info.rowFromClamped ?? 0) >= (info.rowToClamped ?? 0) ? "-> EMPTY (this is why extractRawEsriSubgrid returns null)" : "-> non-empty"}',
    )
    ..write(
      'extractRawEsriSubgrid() returned: ${info.extractionSucceeded ? "a slice" : "null"}',
    );
  return buf.toString();
}

/// Renders a [SwissBathyDebugInfo] as plain, copy-pasteable text.
String formatSwissBathyDebugInfo(SwissBathyDebugInfo info) {
  final buf = StringBuffer()
    ..writeln('DEBUG (temporary) - swissBATHY3D diagnostic')
    ..writeln('site: ${info.siteName} (${info.siteId})')
    ..writeln(
      'site coordinate (WGS84): '
      '${info.siteCoordinate.latitude}, ${info.siteCoordinate.longitude}',
    )
    ..writeln(
      'quantized cell (${info.quantumDeg}°'
      '${info.quantumDeg <= 0 ? ", i.e. unquantized/raw" : ""}): '
      '${info.quantizedCell.lat}, ${info.quantizedCell.lon}',
    )
    ..writeln('outer grid cache key: ${info.outerCacheKey}')
    ..writeln(
      info.quantumDeg <= 0
          ? 'fetch center (the site coordinate itself, unquantized): '
                '${info.fetchCenter.latitude}, ${info.fetchCenter.longitude}'
          : 'fetch center (cell center, NOT the site coordinate): '
                '${info.fetchCenter.latitude}, ${info.fetchCenter.longitude}',
    );
  if (!info.insideSwissLakeCoverage) {
    buf.writeln('outside known Swiss lake coverage (findSwissLake -> null)');
    buf.write(formatSwissBathyCachePathsDebugInfo(info.cachePaths));
    return buf.toString();
  }
  buf.writeln(
    'LV95 (from fetch center): '
    'E=${info.lv95!.easting.toStringAsFixed(1)}, '
    'N=${info.lv95!.northing.toStringAsFixed(1)}',
  );
  buf.writeln('tiles requested (${info.tiles.length}):');
  for (final tile in info.tiles) {
    final checked = tile.checkedAt == null ? '' : ', checked ${tile.checkedAt}';
    final lookupNote = tile.lookupKey == tile.tileKey
        ? ''
        : ' [lookup key differs: ${tile.lookupKey}]';
    final raw = tile.rawFingerprint;
    final rawNote = raw == null
        ? ''
        : ' | raw tile: ${raw.rows}x${raw.cols}, '
              'depth ${raw.minDepth?.toStringAsFixed(2) ?? "n/a"}/'
              '${raw.maxDepth?.toStringAsFixed(2) ?? "n/a"}, '
              'hash=0x${raw.hash.toRadixString(16)}';
    buf.writeln(
      '  ${tile.tileKey}: ${tile.cached ? "cached" : "not cached"}'
      '$checked$lookupNote$rawNote',
    );
  }
  if (info.firstTileStacUrl != null) {
    buf.writeln('first tile STAC query: ${info.firstTileStacUrl}');
  }
  final extraction = info.firstTileExtraction;
  if (extraction != null) {
    buf.writeln(formatSwissBathyExtractionDebugInfo(extraction));
  }
  buf.write(formatSwissBathyCachePathsDebugInfo(info.cachePaths));
  return buf.toString();
}

// ---------------------------------------------------------------------
// TEMPORARY - DEBUG ONLY, remove before upstream PR.
//
// Investigated Bug 11 (two real, independently-meaningful dive sites
// reportedly render a pixel-identical visible 3D profile even though the
// fetch/stitch layer above was proven, with the real coordinates, to
// return different grids). Everything above this point diagnoses the
// FETCH layer; this section instead fingerprints the RENDER layer —
// the actual [MeshData] a [SiteSeascapeGeometryService.buildWithLabels]
// call hands to [Scene3d] — plus records when that call last actually ran
// for a given site, so a stale/reused Scene3d (rather than a stale/reused
// grid) can be told apart from a genuine rebuild that just happens to
// produce the same numbers.
// ---------------------------------------------------------------------

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Timestamp of the
/// last [SiteSeascapeGeometryService.buildWithLabels] call per site id,
/// written by the caller in `site_seascape_providers.dart` right after
/// `built` resolves (both the synchronous and the `compute()`-isolate
/// branch funnel through that one call site back on the main isolate).
/// A plain module-level map is enough here: this is throwaway diagnostic
/// state for a single debugging session, not app state.
final Map<String, DateTime> _swissBathyDebugLastBuiltAt = {};

/// TEMPORARY - DEBUG ONLY, remove before upstream PR.
void recordSwissBathySceneBuilt(String siteId) {
  _swissBathyDebugLastBuiltAt[siteId] = DateTime.now();
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR.
DateTime? swissBathyDebugLastBuiltAtFor(String siteId) =>
    _swissBathyDebugLastBuiltAt[siteId];

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. A cheap, order- and
/// value-sensitive fingerprint of a mesh's flat position buffer, plus when
/// the scene that produced it was last (re)built for [siteId] — everything
/// needed to tell "two sites really did render the same triangles" apart
/// from "the mesh differs but happens to look the same" without shipping
/// the whole array.
///
/// [MeshData.positions] is a flat xyz triplet buffer, but in this codebase's
/// scene frame ([BathymetryTerrainBuilder.build]) the VERTICAL axis a diver
/// reads as depth is the middle component (`positions[vi + 1]`, scene Y —
/// `projection.yOf(depth)`), not the third one: the third component is
/// scene Z, `projection.zOf(north)`, a HORIZONTAL axis. [depthHash] and
/// [horizontalHash] split on that real axis assignment (not on a naive
/// "every third value starting at 2" reading of "xyz"), so they actually
/// test the Bug-11 hypothesis that two sites' identical-looking renders
/// might share depth/color values while differing only in the horizontal
/// placement of those values.
class SwissBathyRenderFingerprint {
  final String siteId;
  final int vertexCount;
  final List<double> firstPositions;
  final List<double> lastPositions;

  /// FNV-1a over the position buffer's raw bytes. Two fingerprints with
  /// the same [vertexCount] but a different [hash] are proof the meshes
  /// differ even if the first/last samples happen to match.
  final int hash;

  /// FNV-1a over ONLY the depth/vertical component of every vertex
  /// (`positions[vi + 1]`, scene Y). If this matches across two sites while
  /// [horizontalHash] differs, the two renders use the same depth/color
  /// values at different horizontal positions — exactly the "identical
  /// noise pattern, different footprint" symptom Bug 11 describes.
  final int depthHash;

  /// FNV-1a over ONLY the horizontal components of every vertex
  /// (`positions[vi]` scene X / east and `positions[vi + 2]` scene Z /
  /// north, interleaved in that order). The complement of [depthHash].
  final int horizontalHash;
  final DateTime? lastBuiltAt;

  const SwissBathyRenderFingerprint({
    required this.siteId,
    required this.vertexCount,
    required this.firstPositions,
    required this.lastPositions,
    required this.hash,
    required this.depthHash,
    required this.horizontalHash,
    required this.lastBuiltAt,
  });
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Builds a
/// [SwissBathyRenderFingerprint] for the terrain mesh currently on screen
/// for [siteId] — read-only, no recomputation of the mesh itself.
SwissBathyRenderFingerprint buildSwissBathyRenderFingerprint({
  required String siteId,
  required MeshData mesh,
}) {
  final positions = mesh.positions;
  final firstCount = positions.length < 3 ? positions.length : 3;
  final lastStart = positions.length < 3 ? 0 : positions.length - 3;
  return SwissBathyRenderFingerprint(
    siteId: siteId,
    vertexCount: mesh.vertexCount,
    firstPositions: positions.sublist(0, firstCount).toList(),
    lastPositions: positions.sublist(lastStart).toList(),
    hash: _fnv1aHashBytes(_bytesOf(positions)),
    depthHash: _fnv1aHashBytes(
      _bytesOf(_extractPositionComponent(positions, 1)),
    ),
    horizontalHash: _fnv1aHashBytes(
      _bytesOf(_extractHorizontalComponents(positions)),
    ),
    lastBuiltAt: swissBathyDebugLastBuiltAtFor(siteId),
  );
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Pulls the single
/// component at [offset] (0 = scene X/east, 1 = scene Y/depth, 2 = scene
/// Z/north — see [SwissBathyRenderFingerprint]'s doc for why 1, not 2, is
/// the depth axis) out of every xyz triplet in [positions].
Float32List _extractPositionComponent(Float32List positions, int offset) {
  final count = positions.length ~/ 3;
  final out = Float32List(count);
  for (var i = 0; i < count; i++) {
    out[i] = positions[i * 3 + offset];
  }
  return out;
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Pulls both horizontal
/// components (scene X/east, scene Z/north) out of every xyz triplet in
/// [positions], interleaved as [x0, z0, x1, z1, ...] — the complement of
/// [_extractPositionComponent] at offset 1.
Float32List _extractHorizontalComponents(Float32List positions) {
  final count = positions.length ~/ 3;
  final out = Float32List(count * 2);
  for (var i = 0; i < count; i++) {
    out[i * 2] = positions[i * 3];
    out[i * 2 + 1] = positions[i * 3 + 2];
  }
  return out;
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. A cheap fingerprint
/// (hash plus min/max/null-count) of the raw [BathymetryGrid]
/// [SiteSeascapeGeometryService.buildWithLabels] receives as input — the
/// grid [SwissBathy3dSource.fetch] returned (stitched across tiles, when
/// the site's span touched more than one), BEFORE any terrain-mesh
/// projection. Sits one layer upstream of [SwissBathyRenderFingerprint]: if
/// two sites' grid fingerprints already match here, the bug is in the fetch
/// layer or something feeding [SiteSeascapeInput.grid] a shared instance —
/// not in the depth/color mapping done while building the mesh.
class SwissBathyGridFingerprint {
  final int rows;
  final int cols;
  final double? minDepth;
  final double? maxDepth;
  final int nullCount;

  /// FNV-1a over every cell's raw depth (LN02-derived meters, `null` cells
  /// folded in as a fixed NaN bit pattern so a run of nodata still moves
  /// the hash instead of being silently skipped).
  final int hash;

  const SwissBathyGridFingerprint({
    required this.rows,
    required this.cols,
    required this.minDepth,
    required this.maxDepth,
    required this.nullCount,
    required this.hash,
  });
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Builds a
/// [SwissBathyGridFingerprint] for [grid] — read-only, no re-fetch.
SwissBathyGridFingerprint buildSwissBathyGridFingerprint(BathymetryGrid grid) {
  double? minDepth;
  double? maxDepth;
  var nullCount = 0;
  final cells = Float64List(grid.depthsMeters.length);
  for (var i = 0; i < grid.depthsMeters.length; i++) {
    final d = grid.depthsMeters[i];
    if (d == null) {
      nullCount++;
      cells[i] = double.nan;
      continue;
    }
    cells[i] = d;
    if (minDepth == null || d < minDepth) minDepth = d;
    if (maxDepth == null || d > maxDepth) maxDepth = d;
  }
  return SwissBathyGridFingerprint(
    rows: grid.rows,
    cols: grid.cols,
    minDepth: minDepth,
    maxDepth: maxDepth,
    nullCount: nullCount,
    hash: _fnv1aHashBytes(_bytesOf(cells)),
  );
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Raw bytes backing a
/// typed-data view, for hashing without any double->string rounding loss.
Uint8List _bytesOf(TypedData values) =>
    values.buffer.asUint8List(values.offsetInBytes, values.lengthInBytes);

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. FNV-1a folded over
/// raw bytes rather than the source double values, so it is exact (no
/// rounding/formatting loss) and cheap enough to run on a tap.
int _fnv1aHashBytes(Uint8List bytes) {
  var hash = 0x811c9dc5;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Renders a
/// [SwissBathyRenderFingerprint] as plain, copy-pasteable text, appended
/// below [formatSwissBathyDebugInfo]'s fetch-layer output.
String formatSwissBathyRenderFingerprint(SwissBathyRenderFingerprint fp) {
  final buf = StringBuffer()
    ..writeln('--- render layer (temporary) ---')
    ..writeln('vertexCount: ${fp.vertexCount}')
    ..writeln('positions[0:3]: ${fp.firstPositions}')
    ..writeln('positions[-3:]: ${fp.lastPositions}')
    ..writeln('positions hash (fnv1a32): 0x${fp.hash.toRadixString(16)}')
    ..writeln(
      'depth-only hash (scene Y, positions[vi+1]) (fnv1a32): '
      '0x${fp.depthHash.toRadixString(16)}',
    )
    ..writeln(
      'horizontal-only hash (scene X+Z, positions[vi]+positions[vi+2]) '
      '(fnv1a32): 0x${fp.horizontalHash.toRadixString(16)}',
    )
    ..write(
      'buildWithLabels() last ran for this site: '
      '${fp.lastBuiltAt?.toIso8601String() ?? "not recorded yet"}',
    );
  return buf.toString();
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Renders a
/// [SwissBathyGridFingerprint] as plain, copy-pasteable text, appended
/// below [formatSwissBathyRenderFingerprint]'s output.
String formatSwissBathyGridFingerprint(SwissBathyGridFingerprint fp) {
  final buf = StringBuffer()
    ..writeln('--- raw stitched grid (temporary) ---')
    ..writeln('rows x cols: ${fp.rows} x ${fp.cols}')
    ..writeln(
      'depth min/max: ${fp.minDepth?.toStringAsFixed(2) ?? "n/a"} / '
      '${fp.maxDepth?.toStringAsFixed(2) ?? "n/a"}',
    )
    ..writeln('nodata cells: ${fp.nullCount} / ${fp.rows * fp.cols}')
    ..write('grid depths hash (fnv1a32): 0x${fp.hash.toRadixString(16)}');
  return buf.toString();
}

// ---------------------------------------------------------------------
// TEMPORARY - DEBUG ONLY, remove before upstream PR.
//
// Investigates a report that swissBATHY3D data reloaded suspiciously fast
// after deleting BOTH AppData\Local\Submersion\submersion and
// AppData\Roaming\Submersion\submersion on Windows — suggesting a third,
// unaccounted-for persistence location. In code, there is only ONE: both
// [SwissBathyTileCacheRepository] (table `swiss_bathy_tile_cache`) and
// [BathymetryRepository] (table `bathymetry_cache`) share a single sqlite
// file opened by [LocalCacheDatabaseService.initialize] via
// getApplicationSupportDirectory() — there is no separate on-disk cache
// for the downloaded zip bytes; [SwissBathy3dSource] keeps those only in
// memory for the duration of one fetch() call. This section surfaces that
// resolved path directly in the app (so it does not have to be re-derived
// on paper per platform) and a debug-only action to clear every
// swissBATHY3D-related row from it, regardless of what a human already
// deleted by hand outside the app.
// ---------------------------------------------------------------------

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. One legacy, pre-rename
/// Windows app-data directory [windows_app_data_migration.migrateCompanyDirectory]
/// would have moved data OUT of on a previous launch — see
/// [buildSwissBathyCachePathsDebugInfo]'s doc for why this matters even
/// after the migration has already run once.
class SwissBathyLegacyPathInfo {
  final String path;
  final bool exists;

  const SwissBathyLegacyPathInfo({required this.path, required this.exists});
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR.
class SwissBathyCachePathsDebugInfo {
  /// The one sqlite file both [SwissBathyTileCacheRepository] and
  /// [BathymetryRepository] read/write, as actually resolved via
  /// getApplicationSupportDirectory() on THIS run.
  final String localCacheDatabasePath;

  /// False when [LocalCacheDatabaseService.instance.database] threw
  /// [StateError] (not yet initialized) — [localCacheDatabasePath] is still
  /// the path it WOULD open, just not confirmed live.
  final bool localCacheDatabaseOpen;

  /// The legacy `<APPDATA|LOCALAPPDATA>/$legacyWindowsCompanyName/$windowsProductName`
  /// directories [migrateWindowsAppDataDirectories] checks on every Windows
  /// launch, with whether each still exists on disk right now. Empty on any
  /// non-Windows platform, or when neither environment variable is set.
  final List<SwissBathyLegacyPathInfo> legacyWindowsPaths;

  const SwissBathyCachePathsDebugInfo({
    required this.localCacheDatabasePath,
    required this.localCacheDatabaseOpen,
    required this.legacyWindowsPaths,
  });
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Re-derives the exact
/// path [LocalCacheDatabaseService.initialize] opens — read-only, issues no
/// network request and does not touch the database beyond checking whether
/// it is already open.
///
/// Also re-derives the legacy Windows company-name directories
/// [migrateWindowsAppDataDirectories] moves data out of on first launch after
/// the rename. That migration only runs the move ONCE: if it fell back to
/// COPYING (same-volume rename can fail e.g. with a file handle still open),
/// the legacy tree is deliberately left in place afterwards (see
/// [AppDataMigrationOutcome.copied]'s doc). A human manually deleting the
/// CURRENT `submersion_local.db` between test runs never touches that
/// retained legacy tree — so if the very first migration on this machine
/// ever copied instead of renamed, the next app launch sees the (now
/// missing) target as empty and copies the legacy tree BACK into place,
/// resurrecting whatever tile cache rows existed back when that first
/// migration ran. This surfaces both legacy directories so that possibility
/// is visible instead of theorized.
Future<SwissBathyCachePathsDebugInfo>
buildSwissBathyCachePathsDebugInfo() async {
  final supportDir = await getApplicationSupportDirectory();
  final dbPath = p.join(supportDir.path, 'Submersion', 'submersion_local.db');
  var open = true;
  try {
    LocalCacheDatabaseService.instance.database;
  } on StateError {
    open = false;
  }
  final legacyPaths = <SwissBathyLegacyPathInfo>[];
  if (Platform.isWindows) {
    for (final variable in const ['APPDATA', 'LOCALAPPDATA']) {
      final root = Platform.environment[variable];
      if (root == null || root.isEmpty) continue;
      final legacyPath = p.join(
        root,
        legacyWindowsCompanyName,
        windowsProductName,
      );
      legacyPaths.add(
        SwissBathyLegacyPathInfo(
          path: legacyPath,
          exists: await Directory(legacyPath).exists(),
        ),
      );
    }
  }
  return SwissBathyCachePathsDebugInfo(
    localCacheDatabasePath: dbPath,
    localCacheDatabaseOpen: open,
    legacyWindowsPaths: legacyPaths,
  );
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Renders a
/// [SwissBathyCachePathsDebugInfo] as plain, copy-pasteable text.
String formatSwissBathyCachePathsDebugInfo(SwissBathyCachePathsDebugInfo info) {
  final buf = StringBuffer()
    ..writeln('--- cache storage locations (temporary) ---')
    ..writeln(
      'path provider call: getApplicationSupportDirectory() '
      '(NOT getApplicationDocumentsDirectory() -- that one only backs the '
      'main dive database -- and NOT getTemporaryDirectory())',
    )
    ..writeln(
      'resolves on this platform to: iOS/macOS -> sandboxed '
      '"Library/Application Support/..."; Android -> app-private support '
      'dir; Linux -> XDG_DATA_HOME (~/.local/share/...); Windows -> '
      r'%APPDATA% (FOLDERID_RoamingAppData) with the app'
      "'s Company/Product name appended twice (see "
      'windows_app_data_migration.dart for the exact segments, including a '
      'legacy pre-rename Company name a stale copy could still sit under)',
    )
    ..writeln('local cache database file: ${info.localCacheDatabasePath}')
    ..writeln(
      'database currently open in this process: '
      '${info.localCacheDatabaseOpen ? "yes" : "NOT open (StateError) -- reads/clears below would fail"}',
    )
    ..writeln(
      'both swiss_bathy_tile_cache (per-1km-tile) AND bathymetry_cache '
      '(per quantized cell / raw coordinate) tables live in that ONE file '
      '-- not two separate files',
    )
    ..writeln(
      'downloaded zip bytes: held in memory only for the duration of one '
      'SwissBathy3dSource.fetch() call, never written to disk -- no '
      'getTemporaryDirectory()/getApplicationCacheDirectory() location '
      'exists for swissBATHY3D specifically (a DIFFERENT, unrelated '
      'getApplicationCacheDirectory() cache exists for draped map tiles in '
      'tile_cache_service.dart, but that caches OSM/topo/satellite imagery '
      'tiles, not swissBATHY3D depth data)',
    );
  if (info.legacyWindowsPaths.isEmpty) {
    buf.write(
      'legacy pre-rename Windows company-name directories: none on this '
      'platform (Windows-only check)',
    );
  } else {
    buf.writeln(
      'legacy pre-rename Windows company-name directories '
      '(windows_app_data_migration.dart, legacyWindowsCompanyName='
      '"$legacyWindowsCompanyName") -- if the migration ever fell back to '
      'COPYING instead of renaming, one of these is retained forever and '
      'gets copied back into the current path above the next time that path '
      'is missing, e.g. after a manual delete:',
    );
    for (var i = 0; i < info.legacyWindowsPaths.length; i++) {
      final legacy = info.legacyWindowsPaths[i];
      final last = i == info.legacyWindowsPaths.length - 1;
      buf.write(
        '  ${legacy.path}: ${legacy.exists ? "EXISTS" : "not present"}'
        '${last ? '' : '\n'}',
      );
    }
  }
  return buf.toString();
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR.
class SwissBathyCacheClearResult {
  final int tileRowsDeleted;
  final int outerCacheRowsDeleted;
  final String path;

  /// How many of [SwissBathyCachePathsDebugInfo.legacyWindowsPaths] were
  /// found on disk and deleted outright (`Directory.delete(recursive: true)`)
  /// — not merely emptied, since the whole legacy company directory is
  /// nothing but retained swissBATHY3D-migration leftovers (see
  /// [buildSwissBathyCachePathsDebugInfo]'s doc). Always 0 on non-Windows
  /// platforms.
  final int legacyDirsDeleted;

  const SwissBathyCacheClearResult({
    required this.tileRowsDeleted,
    required this.outerCacheRowsDeleted,
    required this.path,
    required this.legacyDirsDeleted,
  });
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Deletes every
/// swissBATHY3D-related row from the local cache database: ALL rows in
/// `swiss_bathy_tile_cache` (that table exists for nothing else), plus only
/// the `bathymetry_cache` rows whose center coordinate falls inside a known
/// swissBATHY3D lake (mirrors [BathymetryRepository.quantumDegFor] — that
/// is exactly the set of outer-cache rows a Swiss coordinate can produce,
/// 'ok' and 'empty' alike). Rows belonging to other sources (GMRT/EMODnet/
/// ETOPO) are left untouched, as are all non-bathymetry app data.
///
/// Also deletes, entirely, any legacy pre-rename Windows company-name
/// directory that still exists (see [buildSwissBathyCachePathsDebugInfo]'s
/// doc for why one can survive indefinitely and get copied back into the
/// current path on a later launch) — otherwise a single button press could
/// clear the live database only to have the next app start silently refill
/// it from that retained legacy copy. Returns null when the local cache
/// database is not open.
Future<SwissBathyCacheClearResult?> clearSwissBathyDebugCache() async {
  final LocalCacheDatabase db;
  try {
    db = LocalCacheDatabaseService.instance.database;
  } on StateError {
    return null;
  }

  final tileRowsDeleted = await db.delete(db.swissBathyTileCache).go();

  final outerRows = await db.select(db.bathymetryCache).get();
  final swissKeys = [
    for (final row in outerRows)
      if (findSwissLake(GeoPoint(row.centerLat, row.centerLon)) != null)
        row.cacheKey,
  ];
  var outerCacheRowsDeleted = 0;
  if (swissKeys.isNotEmpty) {
    outerCacheRowsDeleted = await (db.delete(
      db.bathymetryCache,
    )..where((t) => t.cacheKey.isIn(swissKeys))).go();
  }

  final paths = await buildSwissBathyCachePathsDebugInfo();
  var legacyDirsDeleted = 0;
  for (final legacy in paths.legacyWindowsPaths) {
    if (!legacy.exists) continue;
    try {
      await Directory(legacy.path).delete(recursive: true);
      legacyDirsDeleted++;
    } catch (_) {
      // Best effort, same as windows_app_data_migration.dart's own cleanup:
      // a file handle held open elsewhere must not abort the rest of the
      // clear.
    }
  }

  return SwissBathyCacheClearResult(
    tileRowsDeleted: tileRowsDeleted,
    outerCacheRowsDeleted: outerCacheRowsDeleted,
    path: paths.localCacheDatabasePath,
    legacyDirsDeleted: legacyDirsDeleted,
  );
}

/// TEMPORARY - DEBUG ONLY, remove before upstream PR. Renders a
/// [SwissBathyCacheClearResult] as a short, human-readable confirmation.
String formatSwissBathyCacheClearResult(SwissBathyCacheClearResult? result) {
  if (result == null) return 'cache not initialized -- nothing to clear';
  return '${result.tileRowsDeleted} tile row(s) + '
      '${result.outerCacheRowsDeleted} outer cache row(s) + '
      '${result.legacyDirsDeleted} legacy Windows directory(ies) deleted '
      'from ${result.path}';
}
