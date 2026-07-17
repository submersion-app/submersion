import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:submersion/core/services/divelogs/divelogs_models.dart';

class DivelogsApiException implements Exception {
  final int statusCode;
  final String message;
  const DivelogsApiException(this.statusCode, this.message);

  @override
  String toString() => 'DivelogsApiException($statusCode): $message';
}

/// Thin typed wrapper over the divelogs.de REST API.
///
/// Auth is delegated to callbacks (mirrors DropboxApiClient): on 401 the
/// client calls [_onTokenRejected] (which invalidates the manager's token)
/// and retries exactly once with a freshly resolved token.
class DivelogsApiClient {
  DivelogsApiClient({
    required Future<String> Function() getBearerToken,
    required void Function() onTokenRejected,
    http.Client? httpClient,
    Uri? baseUri,
  }) : _getBearerToken = getBearerToken,
       _onTokenRejected = onTokenRejected,
       _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://divelogs.de/api');

  final Future<String> Function() _getBearerToken;
  final void Function() _onTokenRejected;
  final http.Client _http;
  final Uri _baseUri;

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

  /// Fetches the short divelist used for the cheap two-way compare.
  Future<DivelogsDivelistResult> getDivelist() async {
    final response = await _get('/divelist');
    final decoded = _decode(response.body, '/divelist');
    final List<dynamic> rows;
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map && decoded['divelist'] is List) {
      rows = decoded['divelist'] as List;
    } else if (decoded is Map && decoded['dives'] is List) {
      rows = decoded['dives'] as List;
    } else {
      throw const DivelogsApiException(0, 'Unexpected /divelist response');
    }
    final entries = <DivelogsDivelistEntry>[];
    var skipped = 0;
    for (final row in rows) {
      final entry = row is Map
          ? DivelogsDivelistEntry.fromJson(Map<String, dynamic>.from(row))
          : null;
      if (entry == null) {
        skipped++;
      } else {
        entries.add(entry);
      }
    }
    return DivelogsDivelistResult(entries: entries, skippedCount: skipped);
  }

  /// Bulk-create dives (create-only; the caller chunks).
  Future<void> postDives(List<Map<String, dynamic>> dives) async {
    await _send('/dives', method: 'POST', jsonBody: dives);
  }

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

  Future<http.Response> _get(String path) => _send(path);

  Future<http.Response> _send(
    String path, {
    String method = 'GET',
    Object? jsonBody,
  }) async {
    var authRetried = false;
    while (true) {
      final token = await _getBearerToken();
      final uri = _baseUri.replace(path: '${_baseUri.path}$path');
      final headers = {
        'Authorization': 'Bearer $token',
        if (jsonBody != null) 'Content-Type': 'application/json',
      };
      final http.Response response;
      try {
        response = method == 'POST'
            ? await _http.post(
                uri,
                headers: headers,
                body: jsonEncode(jsonBody),
              )
            : await _http.get(uri, headers: headers);
      } on Exception {
        throw const DivelogsApiException(0, 'Could not reach divelogs.de.');
      }
      if (response.statusCode == 401) {
        _onTokenRejected();
        if (!authRetried) {
          authRetried = true;
          continue;
        }
        throw const DivelogsApiException(
          401,
          'divelogs.de sign-in expired. Sign in again in Settings.',
        );
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
