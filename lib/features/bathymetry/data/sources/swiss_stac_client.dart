import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

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

  const SwissBathyAsset({
    required this.href,
    required this.format,
    this.datetime,
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
  /// this was never confirmed against the live API (see the class doc), and
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
    final url = Uri.parse('$baseUrl/collections/$collectionId/items').replace(
      queryParameters: {
        'bbox': bbox.map((v) => v.toString()).join(','),
        'limit': '10',
      },
    );
    final http.Response resp;
    try {
      resp = await _client.get(url).timeout(_itemsTimeout);
    } catch (e) {
      throw SwissStacException('STAC items request failed: $e');
    }
    if (resp.statusCode == 404) {
      throw SwissStacCollectionNotFoundException(collectionId);
    }
    if (resp.statusCode != 200) {
      throw SwissStacException('STAC items HTTP ${resp.statusCode}');
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw SwissStacException('STAC items response not JSON: $e');
    }
    final features = body['features'] as List<dynamic>? ?? const [];
    final candidates = <SwissBathyAsset>[];
    for (final feature in features) {
      final featureMap = feature as Map<String, dynamic>;
      if (!_featureOverlaps(featureMap, bbox)) continue;
      final assets = featureMap['assets'] as Map<String, dynamic>?;
      if (assets == null) continue;
      final picked = _pickAsset(assets);
      if (picked == null) continue;
      final properties = featureMap['properties'] as Map<String, dynamic>?;
      candidates.add(
        SwissBathyAsset(
          href: picked.href,
          format: picked.format,
          datetime: _itemDatetime(properties),
        ),
      );
    }
    return candidates;
  }

  /// Whether STAC item [featureMap]'s own `bbox` genuinely overlaps the
  /// requested [queryBbox]. A missing or malformed `bbox` is treated as no
  /// overlap: a valid STAC item always carries one when it has geometry, so
  /// its absence means the response cannot be trusted for this lookup.
  static bool _featureOverlaps(
    Map<String, dynamic> featureMap,
    List<double> queryBbox,
  ) {
    final raw = featureMap['bbox'] as List<dynamic>?;
    if (raw == null || raw.length < 4) return false;
    final double minLon, minLat, maxLon, maxLat;
    try {
      minLon = (raw[0] as num).toDouble();
      minLat = (raw[1] as num).toDouble();
      maxLon = (raw[2] as num).toDouble();
      maxLat = (raw[3] as num).toDouble();
    } catch (_) {
      return false;
    }
    return minLon <= queryBbox[2] &&
        maxLon >= queryBbox[0] &&
        minLat <= queryBbox[3] &&
        maxLat >= queryBbox[1];
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
      final href = (asset as Map<String, dynamic>?)?['href'] as String?;
      if (href == null) continue;
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
    try {
      resp = await _client.get(Uri.parse(href)).timeout(_downloadTimeout);
    } catch (e) {
      throw SwissStacException('Asset download failed: $e');
    }
    if (resp.statusCode != 200) {
      throw SwissStacException('Asset download HTTP ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }
}
