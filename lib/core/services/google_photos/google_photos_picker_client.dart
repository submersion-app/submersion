import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_models.dart';
import 'package:submersion/core/services/logger_service.dart';

/// A non-2xx response from the Google Photos Picker API. Carries the status
/// code so callers can distinguish auth failures (401) from transient
/// errors.
class GooglePhotosApiException implements Exception {
  const GooglePhotosApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// REST client for the
/// [Google Photos Picker API](https://developers.google.com/photos/picker/reference/rest).
///
/// Lifecycle: [createSession] -> send the user to [PickerSession.pickerUri]
/// -> poll [getSession] until `mediaItemsSet` -> [listMediaItems] ->
/// [downloadBytes] for each -> [deleteSession]. Every request carries the
/// bearer token from [GooglePhotosAuthManager]; a 401 triggers exactly one
/// silent token refresh and retry.
class GooglePhotosPickerClient {
  GooglePhotosPickerClient({
    required GooglePhotosAuthManager auth,
    http.Client? httpClient,
  }) : _auth = auth,
       _http = httpClient ?? http.Client();

  static const String baseUrl = 'https://photospicker.googleapis.com/v1';

  /// Picker API page cap for `mediaItems.list`.
  static const int _pageSize = 100;

  final GooglePhotosAuthManager _auth;
  final http.Client _http;
  final _log = LoggerService.forClass(GooglePhotosPickerClient);

  /// Creates a picker session. The returned [PickerSession.pickerUri] is
  /// what the user opens to choose photos.
  Future<PickerSession> createSession() async {
    final json = await _sendJson('POST', Uri.parse('$baseUrl/sessions'));
    return PickerSession.fromJson(json);
  }

  /// The current state of session [sessionId]. Poll this until
  /// [PickerSession.mediaItemsSet] is true, spacing calls by
  /// [PickerSession.pollInterval].
  Future<PickerSession> getSession(String sessionId) async {
    final json = await _sendJson(
      'GET',
      Uri.parse('$baseUrl/sessions/$sessionId'),
    );
    return PickerSession.fromJson(json);
  }

  /// Discards session [sessionId]. Best-effort cleanup -- the session also
  /// expires on its own -- so a failure here is logged, not thrown.
  Future<void> deleteSession(String sessionId) async {
    try {
      await _send('DELETE', Uri.parse('$baseUrl/sessions/$sessionId'));
    } on Exception catch (e) {
      _log.warning('Picker session $sessionId cleanup failed: $e');
    }
  }

  /// Every media item the user picked in [sessionId], following pagination.
  Future<List<PickedMediaItem>> listMediaItems(String sessionId) async {
    final items = <PickedMediaItem>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$baseUrl/mediaItems').replace(
        queryParameters: {
          'sessionId': sessionId,
          'pageSize': '$_pageSize',
          'pageToken': ?pageToken,
        },
      );
      final json = await _sendJson('GET', uri);
      final list = json['mediaItems'];
      if (list is List) {
        for (final entry in list) {
          if (entry is Map<String, Object?>) {
            items.add(PickedMediaItem.fromJson(entry));
          }
        }
      }
      final next = json['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
    } while (pageToken != null);
    return items;
  }

  /// Downloads [item]'s bytes. With no dimensions this fetches the original
  /// file (`=d`), which carries the EXIF the enrichment step reads; pass
  /// [width]/[height] for a resized rendition (`=w<W>-h<H>`, no EXIF).
  Future<Uint8List> downloadBytes(
    PickedMediaItem item, {
    int? width,
    int? height,
  }) async {
    if (item.baseUrl.isEmpty) {
      throw const GooglePhotosApiException(
        0,
        'Media item has no download URL.',
      );
    }
    final param = (width != null && height != null)
        ? '=w$width-h$height'
        : item.isVideo
        ? '=dv'
        : '=d';
    final uri = Uri.parse('${item.baseUrl}$param');
    final response = await _send('GET', uri);
    return response.bodyBytes;
  }

  Future<Map<String, Object?>> _sendJson(String method, Uri uri) async {
    final response = await _send(method, uri);
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw GooglePhotosApiException(
        response.statusCode,
        'Unexpected response from Google Photos.',
      );
    }
    return decoded;
  }

  Future<http.Response> _send(String method, Uri uri) async {
    var response = await _dispatch(method, uri);
    if (response.statusCode == 401) {
      _auth.invalidateAccessToken();
      response = await _dispatch(method, uri);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GooglePhotosApiException(
        response.statusCode,
        _errorMessage(response),
      );
    }
    return response;
  }

  Future<http.Response> _dispatch(String method, Uri uri) async {
    final token = await _auth.getAccessToken();
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $token';
    try {
      final streamed = await _http.send(request);
      return await http.Response.fromStream(streamed);
    } on http.ClientException catch (e) {
      throw GooglePhotosApiException(0, 'Could not reach Google Photos: $e');
    }
  }

  static String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?> && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } on FormatException {
      // Fall through to the generic message.
    }
    return 'Google Photos request failed (${response.statusCode}).';
  }
}
