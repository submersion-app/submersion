import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';

const _log = LoggerService('SwissStacClient');

/// One selected STAC asset for a swissBATHY3D tile: a ZIP containing the
/// grid file.
class SwissBathyAsset {
  final String href;

  /// 'esri-ascii' when the href looks like an ESRI ASCII grid zip
  /// (preferred, per task design decision — smaller than XYZ), 'unknown'
  /// otherwise (still tried; the downloader falls back to whatever grid file
  /// it finds inside the zip).
  final String format;

  /// The owning STAC item's `datetime` property (falling back to `updated`
  /// then `created` when absent), as a raw ISO-8601 string. Used as an
  /// opaque version token for the periodic tile freshness check
  /// ([SwissBathy3dSource.staleCheckInterval]) — never parsed, only compared
  /// for equality. Null when the item carries none of those properties.
  final String? datetime;

  /// The owning STAC item's own declared `bbox` (WGS84
  /// `[minLon, minLat, maxLon, maxLat]`), when present — used by
  /// `_firstOverlappingCandidate` as a cheap, no-extra-network-cost
  /// pre-filter against a TILE's own bounds before downloading and parsing
  /// a candidate (GitHub Copilot review: since #1764 queries this per
  /// LAKE rather than per tile, a neighboring lake's asset can pass the
  /// wider lake-level bbox check yet still declare a bbox that does not
  /// reach every one of that lake's own tiles). Null when the item
  /// carried no valid bbox, in which case the candidate is never skipped
  /// by that filter — same as everywhere else in this class, an
  /// unrecognized/missing bbox proves nothing about location (Bug 15's
  /// own lesson), so it degrades to the slower-but-correct
  /// always-download behavior instead of silently dropping a real match.
  /// Content validation (`extractRawEsriSubgridFromGrids`) remains the
  /// sole correctness authority regardless — this field only decides what
  /// gets downloaded and parsed AT ALL, exactly like the filename-based
  /// prefilter `_entriesNearTile` already does one layer deeper.
  final ({double minLon, double minLat, double maxLon, double maxLat})? bbox;

  const SwissBathyAsset({
    required this.href,
    required this.format,
    this.datetime,
    this.bbox,
  });
}

/// Thrown on any transient STAC failure (network error, timeout, non-200,
/// unparseable body). Callers must never cache this as a definitive answer.
class SwissStacException implements Exception {
  final String message;
  const SwissStacException(this.message);

  @override
  String toString() => 'SwissStacException: $message';
}

/// Thrown when a collection ID does not exist on the API (HTTP 404 on the
/// collection or its items endpoint) — distinct from [SwissStacException]
/// so callers can fall back to the next candidate ID instead of treating it
/// as a plain transient failure.
class SwissStacCollectionNotFoundException implements Exception {
  final String collectionId;
  const SwissStacCollectionNotFoundException(this.collectionId);

  @override
  String toString() =>
      'SwissStacCollectionNotFoundException: $collectionId not found';
}

/// Minimal client for the swisstopo STAC API (data.geo.admin.ch), scoped to
/// looking up the swissBATHY3D asset covering one bounding box.
///
/// [collectionIds] lists candidate collection IDs to try in order. The primary
/// ID is currently `ch.swisstopo.swissbathy3d`; additional IDs can be added if
/// swisstopo changes naming in the future.
class SwissStacClient {
  static const List<String> collectionIds = ['ch.swisstopo.swissbathy3d'];

  /// Timeout for a STAC items metadata lookup — a small JSON response, so 15
  /// seconds stays generous without letting one slow lake stall a fetch that
  /// may need to look up dozens of tiles.
  static const Duration _itemsTimeout = Duration(seconds: 15);

  /// Timeout for downloading an asset ZIP. A lake-wide swissBATHY3D grid can
  /// be tens of megabytes, and this app has been observed timing out at the
  /// old 15-second value on ordinary connections — 120 seconds gives a large
  /// download real room without waiting forever on a genuinely dead
  /// connection.
  static const Duration _downloadTimeout = Duration(seconds: 120);

  final http.Client _client;
  final String baseUrl;

  SwissStacClient({
    http.Client? client,
    this.baseUrl = 'https://data.geo.admin.ch/api/stac/v1',
  }) : _client = client ?? http.Client();

  /// The best single asset for [bbox] — the first of [findAssetCandidates],
  /// or null when none match. Most callers only need one candidate; see
  /// [findAssetCandidates]'s doc for why some need every plausible one.
  Future<SwissBathyAsset?> findAsset({
    required String collectionId,
    required List<double> bbox,
  }) async {
    final candidates = await findAssetCandidates(
      collectionId: collectionId,
      bbox: bbox,
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Finds every plausible asset among the items intersecting [bbox]
  /// (WGS84: [minLon, minLat, maxLon, maxLat]) in [collectionId], in the
  /// order the server returned them.
  ///
  /// The `bbox` query parameter asks the server to filter spatially, but
  /// even a compliant server can legitimately return a neighboring tile
  /// whose bbox merely overlaps the query's edge buffer. Trusting the first
  /// feature blindly would silently splice an unrelated tile into the
  /// stitched mosaic — a real mesh, just not for the requested ground —
  /// which is indistinguishable from correct data until a marker turns up
  /// far outside it. So every candidate's OWN `bbox` is re-checked against
  /// [bbox] here; a feature whose footprint does not actually overlap the
  /// request is skipped rather than trusted.
  ///
  /// Returning every match rather than just the first lets a caller fall
  /// through to the next candidate when the first one's actual downloaded
  /// content turns out not to cover the requested ground after all — a
  /// declared item `bbox` can be coarser or simply wrong relative to its own
  /// raster's real footprint, which [_featureOverlaps] alone cannot detect
  /// (it only has the server's word for it, not the pixels).
  ///
  /// Returns an empty list when the collection exists but no item/asset
  /// covers the box — a definitive "no tile here", safe to cache as a
  /// negative result once every candidate has been tried. Throws
  /// [SwissStacCollectionNotFoundException] when [collectionId] itself does
  /// not exist, [SwissStacException] on any other transient failure.
  Future<List<SwissBathyAsset>> findAssetCandidates({
    required String collectionId,
    required List<double> bbox,
  }) async {
    final candidates = <SwissBathyAsset>[];
    Uri? url = Uri.parse('$baseUrl/collections/$collectionId/items').replace(
      queryParameters: {
        'bbox': bbox.map((v) => v.toString()).join(','),
        'limit': '100',
      },
    );
    // A single ~1km tile bbox should never legitimately intersect enough
    // items to need more than a handful of pages; this cap bounds a
    // pathological or misbehaving server rather than paging forever.
    const maxPages = 10;
    for (var page = 0; page < maxPages && url != null; page++) {
      final http.Response resp;
      final stopwatch = Stopwatch()..start();
      try {
        resp = await _client.get(url).timeout(_itemsTimeout);
      } catch (e) {
        // Warnings are persisted to the on-disk log even with Debug-Modus
        // off (#1826), but this request's `url` carries the `bbox` query
        // parameter -- a real location -- so, like
        // BathymetryRepository._guardedLoad's own doc explains, the
        // coordinate-bearing detail stays at debug level (gated behind
        // Debug-Modus) while the always-persisted warning itself names
        // only what happened, never where (GitHub Copilot review).
        _log.warning(
          'items request failed after ${stopwatch.elapsedMilliseconds}ms',
          error: e,
        );
        _log.debug(
          'items request failed after ${stopwatch.elapsedMilliseconds}ms: '
          '$url',
        );
        throw SwissStacException('STAC items request failed: $e');
      }
      if (resp.statusCode == 404) {
        _log.warning('items request 404');
        _log.debug('items request 404: $url');
        throw SwissStacCollectionNotFoundException(collectionId);
      }
      if (resp.statusCode != 200) {
        _log.warning(
          'items request HTTP ${resp.statusCode} after '
          '${stopwatch.elapsedMilliseconds}ms',
        );
        _log.debug(
          'items request HTTP ${resp.statusCode} after '
          '${stopwatch.elapsedMilliseconds}ms: $url | body: '
          '${_truncate(resp.body)}',
        );
        throw SwissStacException('STAC items HTTP ${resp.statusCode}');
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(resp.body);
      } catch (e) {
        throw SwissStacException('STAC items response not JSON: $e');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const SwissStacException(
          'STAC items response was not a JSON object',
        );
      }
      final body = decoded;
      final rawFeatures = body['features'];
      if (rawFeatures != null && rawFeatures is! List) {
        throw const SwissStacException(
          "STAC items response's 'features' field was not a list",
        );
      }
      final features = rawFeatures is List ? rawFeatures : const <dynamic>[];
      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;
        if (!_featureOverlaps(feature, bbox)) continue;
        final assets = feature['assets'];
        if (assets is! Map<String, dynamic>) continue;
        final picked = _pickAsset(assets);
        if (picked == null) continue;
        final properties = feature['properties'];
        candidates.add(
          SwissBathyAsset(
            href: picked.href,
            format: picked.format,
            datetime: _itemDatetime(
              properties is Map<String, dynamic> ? properties : null,
            ),
            bbox: _parseFeatureBbox(feature),
          ),
        );
      }
      url = _nextPageUrl(body);
      if (url != null && page == maxPages - 1) {
        // A "next" link still exists but the page cap was just reached: the
        // candidate list above is definitely incomplete, not "no tile
        // here". Returning it would let a caller cache a false negative for
        // a tile that a later page might actually cover. Throwing keeps
        // this a transient failure (retried on the next visit) instead.
        throw const SwissStacException(
          'STAC items pagination exceeded $maxPages pages; refusing '
          'partial results',
        );
      }
    }
    return candidates;
  }

  /// The STAC `next` pagination link's href, if the response declares one
  /// (OGC API Features / STAC `links` array with `"rel": "next"`), else null.
  /// A malformed `links` array (missing entirely, not a list, or containing
  /// non-object entries) is treated the same as "no next link" rather than
  /// thrown — this is best-effort continuation, not a required field, so a
  /// server sending unexpected shapes here should not abort an otherwise
  /// successful page of results.
  static Uri? _nextPageUrl(Map<String, dynamic> body) {
    final links = body['links'];
    if (links is! List) return null;
    for (final link in links) {
      if (link is! Map<String, dynamic>) continue;
      if (link['rel'] != 'next') continue;
      final href = link['href'];
      if (href is! String) continue;
      return Uri.tryParse(href);
    }
    return null;
  }

  /// STAC item [featureMap]'s own declared `bbox`, parsed to WGS84
  /// `(minLon, minLat, maxLon, maxLat)`, or null when it is missing or
  /// malformed. Shared by [_featureOverlaps] (the query-time filter) and
  /// [findAssetCandidates] (which retains it on [SwissBathyAsset] for
  /// `_firstOverlappingCandidate`'s own later per-tile pre-filter).
  static ({double minLon, double minLat, double maxLon, double maxLat})?
  _parseFeatureBbox(Map<String, dynamic> featureMap) {
    final raw = featureMap['bbox'];
    if (raw is! List || raw.length < 4) return null;
    final rawMinLon = raw[0];
    final rawMinLat = raw[1];
    final rawMaxLon = raw[2];
    final rawMaxLat = raw[3];
    if (rawMinLon is! num ||
        rawMinLat is! num ||
        rawMaxLon is! num ||
        rawMaxLat is! num) {
      return null;
    }
    return (
      minLon: rawMinLon.toDouble(),
      minLat: rawMinLat.toDouble(),
      maxLon: rawMaxLon.toDouble(),
      maxLat: rawMaxLat.toDouble(),
    );
  }

  /// Whether STAC item [featureMap]'s own `bbox` genuinely overlaps the
  /// requested [queryBbox]. A missing or malformed `bbox` is treated as no
  /// overlap: a valid STAC item always carries one when it has geometry, so
  /// its absence means the response cannot be trusted for this lookup.
  static bool _featureOverlaps(
    Map<String, dynamic> featureMap,
    List<double> queryBbox,
  ) {
    final bbox = _parseFeatureBbox(featureMap);
    if (bbox == null) return false;
    return bbox.minLon <= queryBbox[2] &&
        bbox.maxLon >= queryBbox[0] &&
        bbox.minLat <= queryBbox[3] &&
        bbox.maxLat >= queryBbox[1];
  }

  /// `properties.datetime`, falling back to `updated` then `created` — STAC
  /// items always carry at least one of these. Used only as an opaque
  /// version token, never parsed as a date.
  static String? _itemDatetime(Map<String, dynamic>? properties) {
    if (properties == null) return null;
    for (final key in const ['datetime', 'updated', 'created']) {
      final value = properties[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static ({String href, String format})? _pickAsset(
    Map<String, dynamic> assets,
  ) {
    ({String href, String format})? bestGrid;
    ({String href, String format})? anyZip;
    for (final asset in assets.values) {
      if (asset is! Map<String, dynamic>) continue;
      final href = asset['href'];
      if (href is! String) continue;
      final lower = href.toLowerCase();
      if (!lower.endsWith('.zip')) continue;
      final looksLikeGrid = lower.contains('grid') || lower.contains('asc');
      final looksLikeXyz = lower.contains('xyz');
      if (looksLikeGrid && !looksLikeXyz) {
        bestGrid ??= (href: href, format: 'esri-ascii');
      }
      anyZip ??= (href: href, format: 'unknown');
    }
    return bestGrid ?? anyZip;
  }

  /// Downloads the asset ZIP at [href].
  Future<Uint8List> downloadBytes(String href) async {
    final http.Response resp;
    final stopwatch = Stopwatch()..start();
    try {
      resp = await _client.get(Uri.parse(href)).timeout(_downloadTimeout);
    } catch (e) {
      // Same privacy split as findAssetCandidates' own warnings: [href]
      // names the specific lake asset (e.g. ".../swissbathy3d_walensee/
      // ...zip"), so it stays out of the always-persisted warning and
      // only reaches the debug-level, Debug-Modus-gated line.
      _log.warning(
        'asset download failed after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
      );
      _log.debug(
        'asset download failed after ${stopwatch.elapsedMilliseconds}ms: '
        '$href',
      );
      throw SwissStacException('Asset download failed: $e');
    }
    if (resp.statusCode != 200) {
      _log.warning(
        'asset download HTTP ${resp.statusCode} after '
        '${stopwatch.elapsedMilliseconds}ms',
      );
      _log.debug(
        'asset download HTTP ${resp.statusCode} after '
        '${stopwatch.elapsedMilliseconds}ms: $href',
      );
      throw SwissStacException('Asset download HTTP ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }

  /// First 200 UTF-16 code units of [body], for a log line that must never
  /// embed an unbounded server response. Backs off to 199 when code unit
  /// 199 is a lead (high) surrogate, so a non-BMP character (an emoji, some
  /// CJK extension characters) straddling the cut is dropped whole rather
  /// than split into an unpaired surrogate.
  static String _truncate(String body) {
    if (body.length <= 200) return body;
    var cut = 200;
    final lead = body.codeUnitAt(cut - 1);
    if (lead >= 0xD800 && lead <= 0xDBFF) cut--;
    return '${body.substring(0, cut)}...';
  }
}
