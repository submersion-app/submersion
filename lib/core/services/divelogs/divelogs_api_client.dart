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
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const DivelogsApiException(0, 'Unexpected /user response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<DivelogsDivesResult> getAllDives() async {
    final response = await _get('/dives');
    final decoded = jsonDecode(response.body);
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

  Future<http.Response> _get(String path) async {
    var authRetried = false;
    while (true) {
      final token = await _getBearerToken();
      final http.Response response;
      try {
        response = await _http.get(
          _baseUri.replace(path: '${_baseUri.path}$path'),
          headers: {'Authorization': 'Bearer $token'},
        );
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
