import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:submersion/core/services/divelogs/divelogs_models.dart';

class DivelogsApiException implements Exception {
  final int statusCode;
  final String message;
  const DivelogsApiException(this.statusCode, this.message);

  @override
  String toString() => 'DivelogsApiException($statusCode): $message';
}

/// divelogs.de still refused a request that carried the session token after
/// renewing it once: the session cannot be used, as opposed to a picture
/// host that simply wants credentials it was never sent.
class DivelogsUnauthorizedException extends DivelogsApiException {
  const DivelogsUnauthorizedException()
    : super(401, 'divelogs.de sign-in expired.');
}

/// Thin typed read-only wrapper over the divelogs.de REST API.
///
/// Auth is delegated to callbacks (mirrors DropboxApiClient): on 401 the
/// client calls [_onTokenRejected] (which invalidates the auth's token)
/// and retries exactly once with a freshly resolved token. A token that
/// cannot be resolved at all throws from [_getBearerToken] and propagates
/// unchanged.
class DivelogsApiClient {
  DivelogsApiClient({
    required Future<String> Function() getBearerToken,
    required void Function() onTokenRejected,
    http.Client? httpClient,
    Uri? baseUri,
    Duration pictureTimeout = const Duration(seconds: 60),
  }) : _getBearerToken = getBearerToken,
       _onTokenRejected = onTokenRejected,
       _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://divelogs.de/api'),
       _pictureTimeout = pictureTimeout;

  final Future<String> Function() _getBearerToken;
  final void Function() _onTokenRejected;
  final http.Client _http;
  final Uri _baseUri;

  /// How long one picture download may take before it counts as failed, so
  /// a stalled connection cannot hang the import after the dives are saved.
  final Duration _pictureTimeout;

  Future<Map<String, dynamic>> getUser() async {
    final response = await _get('/user');
    final decoded = _decode(response.body, '/user');
    if (decoded is! Map) {
      throw const DivelogsApiException(0, 'Unexpected /user response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<DivelogsDivesResult> getAllDives() async {
    final response = await _get('/dives');
    final decoded = _decode(response.body, '/dives');
    final List<dynamic> rawDives;
    if (decoded is List) {
      rawDives = decoded;
    } else if (decoded is Map && decoded['dives'] is List) {
      rawDives = decoded['dives'] as List;
    } else {
      throw const DivelogsApiException(0, 'Unexpected /dives response');
    }
    final dives = <DivelogsDive>[];
    var skipped = 0;
    for (final raw in rawDives) {
      if (raw is! Map) {
        skipped++;
        continue;
      }
      try {
        dives.add(DivelogsDive.fromJson(Map<String, dynamic>.from(raw)));
      } on FormatException {
        skipped++;
      }
    }
    return DivelogsDivesResult(dives: dives, skippedCount: skipped);
  }

  Future<List<DivelogsGearItem>> getGear() async {
    final response = await _get('/gear');
    final rows = _rows(_decode(response.body, '/gear'), '/gear', const [
      'gear',
      'gearitems',
    ]);
    return [
      for (final row in rows)
        if (row is Map)
          ...?_maybe(DivelogsGearItem.fromJson(Map<String, dynamic>.from(row))),
    ];
  }

  Future<List<DivelogsCertification>> getCertifications() async {
    final response = await _get('/certifications');
    final rows = _rows(
      _decode(response.body, '/certifications'),
      '/certifications',
      const ['certifications'],
    );
    return [
      for (final row in rows)
        if (row is Map)
          ...?_maybe(
            DivelogsCertification.fromJson(Map<String, dynamic>.from(row)),
          ),
    ];
  }

  /// Geartype reference list: id -> display name. Accepts array-of-objects,
  /// wrapped, or id->name map forms (shape unconfirmed, spec open question).
  Future<Map<int, String>> getGeartypes() async {
    final response = await _get('/geartypes');
    final decoded = _decode(response.body, '/geartypes');
    final result = <int, String>{};
    if (decoded is Map && decoded.values.every((v) => v is String)) {
      decoded.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null) result[id] = v as String;
      });
      return result;
    }
    final rows = _rows(decoded, '/geartypes', const ['geartypes']);
    for (final row in rows) {
      if (row is Map) {
        final id = row['id'];
        final name = row['name'];
        if (id is num && name is String) result[id.toInt()] = name;
      }
    }
    return result;
  }

  Future<List<DivelogsPicture>> getPictures(String diveId) async {
    // One path segment whatever the id holds: a `/`, `?` or `#` in it must
    // not address another route.
    final response = await _get('/pictures/${Uri.encodeComponent(diveId)}');
    final rows = _rows(_decode(response.body, '/pictures'), '/pictures', const [
      'pictures',
    ]);
    return [
      for (final row in rows)
        if (row is Map)
          ...?_maybe(DivelogsPicture.fromJson(Map<String, dynamic>.from(row))),
    ];
  }

  /// Fetches picture bytes from an absolute URL (NOT a /api path).
  ///
  /// The session token goes only to the API's own host (or a subdomain of
  /// it) over https, with the same 401-invalidate-retry-once contract; a
  /// picture served from anywhere else is fetched without it, so the token
  /// never reaches a third party or crosses the network in the clear.
  ///
  /// An http link on the API's own host is fetched over https instead, so it
  /// still gets the token without the token ever travelling in the clear.
  Future<Uint8List> downloadPictureBytes(Uri url) async {
    final onApiHost = _isApiHost(url);
    final target = onApiHost && url.isScheme('http')
        ? url.replace(scheme: 'https')
        : url;
    final response = onApiHost && target.isScheme('https')
        ? await _authorizedGet(target, timeout: _pictureTimeout)
        : await _plainGet(target);
    return response.bodyBytes;
  }

  bool _isApiHost(Uri url) {
    final host = url.host.toLowerCase();
    final apiHost = _baseUri.host.toLowerCase();
    return host == apiHost || host.endsWith('.$apiHost');
  }

  Future<http.Response> _plainGet(Uri uri) async {
    final http.Response response;
    try {
      response = await _http.get(uri).timeout(_pictureTimeout);
    } on Exception {
      throw const DivelogsApiException(0, 'Could not download the picture.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DivelogsApiException(
        response.statusCode,
        'Picture download failed (${response.statusCode})',
      );
    }
    return response;
  }

  List<dynamic> _rows(Object? decoded, String endpoint, List<String> listKeys) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in listKeys) {
        if (decoded[key] is List) return decoded[key] as List;
      }
    }
    throw DivelogsApiException(0, 'Unexpected $endpoint response');
  }

  List<T>? _maybe<T>(T? value) => value == null ? null : [value];

  /// Decodes a response body, converting FormatException (non-JSON error
  /// pages, proxy-injected HTML) into the retryable DivelogsApiException the
  /// UI already handles.
  Object? _decode(String body, String endpoint) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw DivelogsApiException(0, 'Unexpected $endpoint response');
    }
  }

  Future<http.Response> _get(String path) =>
      _authorizedGet(_baseUri.replace(path: '${_baseUri.path}$path'));

  Future<http.Response> _authorizedGet(Uri uri, {Duration? timeout}) async {
    var authRetried = false;
    while (true) {
      final token = await _getBearerToken();
      final http.Response response;
      try {
        final request = _http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );
        response = await (timeout == null ? request : request.timeout(timeout));
      } on Exception {
        throw const DivelogsApiException(0, 'Could not reach divelogs.de.');
      }
      if (response.statusCode == 401) {
        _onTokenRejected();
        if (!authRetried) {
          authRetried = true;
          continue;
        }
        throw const DivelogsUnauthorizedException();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DivelogsApiException(
          response.statusCode,
          'divelogs.de API error ${response.statusCode}',
        );
      }
      return response;
    }
  }
}
