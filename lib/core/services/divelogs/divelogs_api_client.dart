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

  Future<void> postGear(Map<String, dynamic> gear) async {
    await _send('/gear', method: 'POST', jsonBody: gear);
  }

  /// Certifications are created via multipart form-data (the endpoint also
  /// accepts scan uploads, deferred to Phase 4). Same 401-retry-once
  /// semantics as [_send]; the request is rebuilt for each attempt.
  Future<void> postCertification({
    required String name,
    required String date,
    String? org,
  }) async {
    var authRetried = false;
    while (true) {
      final token = await _getBearerToken();
      final request = http.MultipartRequest(
        'POST',
        _baseUri.replace(path: '${_baseUri.path}/certifications'),
      )..headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = name;
      request.fields['date'] = date;
      if (org != null) request.fields['org'] = org;
      final http.Response response;
      try {
        response = await http.Response.fromStream(await _http.send(request));
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
      return;
    }
  }

  Future<List<DivelogsPicture>> getPictures(String diveId) async {
    final response = await _get('/pictures/$diveId');
    final rows = _rows(_decode(response.body, '/pictures'), '/pictures', const [
      'pictures',
    ]);
    return [
      for (final row in rows)
        if (row is Map)
          ...?_maybe(DivelogsPicture.fromJson(Map<String, dynamic>.from(row))),
    ];
  }

  /// Fetches picture bytes from an absolute URL (NOT a /api path), reusing
  /// the same bearer + 401-invalidate-retry-once contract.
  Future<Uint8List> downloadPictureBytes(Uri url) async {
    var authRetried = false;
    while (true) {
      final token = await _getBearerToken();
      final http.Response response;
      try {
        response = await _http.get(
          url,
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
      return response.bodyBytes;
    }
  }

  /// Uploads a picture to a dive via multipart form-data (field `imagefile`).
  /// Same 401-retry-once semantics; the request is rebuilt per attempt.
  Future<void> postPicture(
    String diveId, {
    required List<int> bytes,
    required String filename,
  }) async {
    var authRetried = false;
    while (true) {
      final token = await _getBearerToken();
      final request = http.MultipartRequest(
        'POST',
        _baseUri.replace(path: '${_baseUri.path}/pictures/$diveId'),
      )..headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('imagefile', bytes, filename: filename),
      );
      final http.Response response;
      try {
        response = await http.Response.fromStream(await _http.send(request));
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
      return;
    }
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
