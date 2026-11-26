/// Sizes Synology Photos renders for a shared item.
///
/// `sm` and `m` are grid sizes (about 320 px on the short edge), `xl` is a
/// screen-sized rendition (about 1280 px on the short edge).
enum SynologyThumbnailSize { sm, m, xl }

/// A Synology Photos share, recognised from its link or from an API URL this
/// feature built for it.
///
/// A share link looks like `https://<host>[:port][/photo]/mo/sharing/<code>`.
/// All API calls go to `<prefix>/mo/sharing/webapi/entry.cgi` on the same
/// origin. Only HTTPS is accepted: the share password and the session cookie
/// would otherwise travel in clear text.
///
/// The API behind share links is not documented by Synology; see
/// `docs/design/specs/2026-11-21-synology-photos-shared-album-design.md`.
class SynologyShareLink {
  const SynologyShareLink._({
    required this.origin,
    required this.code,
    required this.pathPrefix,
  });

  /// Scheme, host and port of the NAS, without a path.
  final Uri origin;

  /// The share code from the link (`passphrase` / `sharing_id` in the API).
  final String code;

  /// `''`, or `'/photo'` when DSM serves Synology Photos under that prefix.
  final String pathPrefix;

  static const _entryPath = '/mo/sharing/webapi/entry.cgi';
  static final _codePattern = RegExp(r'^[A-Za-z0-9_-]+$');
  static final _sharePath = RegExp(r'^(/photo)?/mo/sharing/([^/]+)/?$');
  static final _apiPath = RegExp(r'^(/photo)?/mo/sharing/webapi/entry\.cgi$');

  /// Identifies the share across hosts and codes, for caches keyed by share.
  String get key => '$origin|$pathPrefix|$code';

  /// The endpoint every API call goes to.
  Uri get apiUri => origin.replace(path: '$pathPrefix$_entryPath');

  /// The share link a user would paste.
  Uri get shareUri => origin.replace(path: '$pathPrefix/mo/sharing/$code');

  /// A share link pasted by the user, or null when [uri] is not one.
  /// [tryParseShareLink] for a stored URL string; null for one that does not
  /// even parse (a malformed row synced from elsewhere).
  static SynologyShareLink? tryParseShareUrl(String raw) {
    final uri = Uri.tryParse(raw);
    return uri == null ? null : tryParseShareLink(uri);
  }

  static SynologyShareLink? tryParseShareLink(Uri uri) {
    if (!_isHttpsWithHost(uri)) return null;
    final match = _sharePath.firstMatch(uri.path);
    if (match == null) return null;
    final code = match.group(2)!;
    if (code == 'webapi' || !_codePattern.hasMatch(code)) return null;
    return SynologyShareLink._(
      origin: _originOf(uri),
      code: code,
      pathPrefix: match.group(1) ?? '',
    );
  }

  /// The share an API URL built by this class belongs to, or null.
  static SynologyShareLink? tryParseApiUri(Uri uri) {
    if (!_isHttpsWithHost(uri)) return null;
    final match = _apiPath.firstMatch(uri.path);
    if (match == null) return null;
    final code = uri.queryParameters['_sharing_id'];
    if (code == null || !_codePattern.hasMatch(code)) return null;
    return SynologyShareLink._(
      origin: _originOf(uri),
      code: code,
      pathPrefix: match.group(1) ?? '',
    );
  }

  /// [tryParseShareLink], then [tryParseApiUri].
  static SynologyShareLink? tryParseAny(Uri uri) =>
      tryParseShareLink(uri) ?? tryParseApiUri(uri);

  /// The original file of item [id]. Carries `id` and `cache_key` as extra
  /// parameters (the API ignores them) so a thumbnail can be derived from the
  /// one URL a media row stores; see [thumbnailFor].
  Uri originalUri({required int id, required String cacheKey}) =>
      apiUri.replace(
        queryParameters: {
          'api': 'SYNO.Foto.Download',
          'method': 'download',
          'version': '2',
          'force_download': 'true',
          'item_id': '[$id]',
          'passphrase': code,
          'download_type': 'source',
          '_sharing_id': code,
          'id': '$id',
          'cache_key': cacheKey,
        },
      );

  /// A rendition of item [id] at [size].
  Uri thumbnailUri({
    required int id,
    required String cacheKey,
    required SynologyThumbnailSize size,
  }) => apiUri.replace(
    queryParameters: {
      'api': 'SYNO.Foto.Thumbnail',
      'method': 'get',
      'version': '2',
      'id': '$id',
      'cache_key': cacheKey,
      'type': 'unit',
      'size': size.name,
      '_sharing_id': code,
    },
  );

  /// Video item [id] streamed at [quality], one of the conversions the item
  /// lists in `video_convert` (`high` is Synology's 720p rendition). Plain
  /// MP4 that honours Range. Carries `cache_key` for [thumbnailFor], like
  /// [originalUri].
  ///
  /// [downloadsAllowed] false marks the URL (`dl=0`, ignored by the API) so
  /// [originalFor] offers no original the share would refuse.
  Uri streamUri({
    required int id,
    required String cacheKey,
    String quality = 'high',
    bool downloadsAllowed = true,
  }) => apiUri.replace(
    queryParameters: {
      'api': 'SYNO.Foto.Streaming',
      'method': 'streaming',
      'version': '2',
      'id': '$id',
      'quality': quality,
      'passphrase': code,
      '_sharing_id': code,
      'cache_key': cacheKey,
      if (!downloadsAllowed) 'dl': '0',
    },
  );

  /// Whether [stored] streams a conversion rather than serving the
  /// original file.
  static bool isStream(Uri stored) =>
      tryParseApiUri(stored) != null &&
      stored.queryParameters['api'] == 'SYNO.Foto.Streaming';

  /// The original file of the item a stored URL points at, for playing a
  /// video in full quality instead of its conversion; null when [stored] is
  /// no share URL, or one of a share that allows no downloads.
  static Uri? originalFor(Uri stored) {
    final link = tryParseApiUri(stored);
    if (link == null || stored.queryParameters['dl'] == '0') return null;
    final id = int.tryParse(stored.queryParameters['id'] ?? '');
    final cacheKey = stored.queryParameters['cache_key'];
    if (id == null || cacheKey == null || cacheKey.isEmpty) return null;
    return link.originalUri(id: id, cacheKey: cacheKey);
  }

  /// The [size] thumbnail of the item a stored URL ([originalUri],
  /// [streamUri] or [thumbnailUri]) points at, or null when [stored] is not
  /// such a URL.
  static Uri? thumbnailFor(Uri stored, SynologyThumbnailSize size) {
    final link = tryParseApiUri(stored);
    if (link == null) return null;
    final id = int.tryParse(stored.queryParameters['id'] ?? '');
    final cacheKey = stored.queryParameters['cache_key'];
    if (id == null || cacheKey == null || cacheKey.isEmpty) return null;
    return link.thumbnailUri(id: id, cacheKey: cacheKey, size: size);
  }

  static bool _isHttpsWithHost(Uri uri) =>
      uri.scheme == 'https' && uri.host.isNotEmpty;

  static Uri _originOf(Uri uri) => Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );

  @override
  String toString() => 'SynologyShareLink($origin$pathPrefix)';
}
