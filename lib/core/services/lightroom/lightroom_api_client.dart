import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_models.dart';

/// A non-2xx response from the Lightroom partner API. Carries the status
/// code so callers can distinguish auth failures (401) from transient
/// errors.
class LightroomApiException implements Exception {
  const LightroomApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// REST client for the Lightroom partner API (https://lr.adobe.io).
///
/// Every JSON response body from this API is prefixed with the abuse-guard
/// string `while (1) {}` which must be stripped before decoding.
class LightroomApiClient {
  LightroomApiClient({
    required AdobeImsAuthManager auth,
    http.Client? httpClient,
  }) : _auth = auth,
       _http = httpClient ?? http.Client();

  static const String baseUrl = 'https://lr.adobe.io';

  static const String _abuseGuard = 'while (1) {}';

  final AdobeImsAuthManager _auth;
  final http.Client _http;

  static String stripAbuseGuard(String body) {
    var s = body;
    if (s.startsWith(_abuseGuard)) {
      s = s.substring(_abuseGuard.length);
    }
    return s.trimLeft();
  }

  /// The web URL of an asset on lightroom.adobe.com ("Open in Lightroom").
  static String assetWebUrl(String catalogId, String assetId) =>
      'https://lightroom.adobe.com/libraries/$catalogId/assets/$assetId';

  Future<LightroomAccount> getAccount() async {
    final json = await _getJson(Uri.parse('$baseUrl/v2/account'));
    return LightroomAccount(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
    );
  }

  Future<String> getCatalogId() async {
    final json = await _getJson(Uri.parse('$baseUrl/v2/catalog'));
    return json['id'] as String;
  }

  Future<List<LightroomAlbum>> listAlbums(String catalogId) async {
    final albums = <LightroomAlbum>[];
    Uri? uri = Uri.parse(
      '$baseUrl/v2/catalogs/$catalogId/albums',
    ).replace(queryParameters: {'subtype': 'collection'});
    while (uri != null) {
      final json = await _getJson(uri);
      for (final resource in _resources(json)) {
        final payload =
            resource['payload'] as Map<String, Object?>? ?? const {};
        albums.add(
          LightroomAlbum(
            id: resource['id'] as String,
            name: payload['name'] as String? ?? 'Untitled',
          ),
        );
      }
      final next = _nextUrl(json);
      uri = next == null ? null : Uri.parse(next);
    }
    return albums;
  }

  /// One page of catalog assets (images and videos), capture-date filtered.
  /// Pass [nextUrl] from a previous page to continue; it wins over the
  /// filter parameters.
  Future<LightroomAssetPage> listAssets(
    String catalogId, {
    DateTime? capturedAfter,
    DateTime? capturedBefore,
    String? nextUrl,
  }) async {
    final uri = nextUrl != null
        ? Uri.parse(nextUrl)
        : Uri.parse('$baseUrl/v2/catalogs/$catalogId/assets').replace(
            queryParameters: {
              'subtype': 'image;video',
              'captured_after': ?_isoWallClock(capturedAfter),
              'captured_before': ?_isoWallClock(capturedBefore),
            },
          );
    final json = await _getJson(uri);
    return LightroomAssetPage(
      assets: [
        for (final resource in _resources(json))
          LightroomAsset.fromResource(resource),
      ],
      nextUrl: _nextUrl(json),
    );
  }

  /// One page of an album's assets with the asset entity embedded. Rows
  /// without an embedded asset are skipped.
  Future<LightroomAssetPage> listAlbumAssets(
    String catalogId,
    String albumId, {
    String? nextUrl,
  }) async {
    final uri = nextUrl != null
        ? Uri.parse(nextUrl)
        : Uri.parse(
            '$baseUrl/v2/catalogs/$catalogId/albums/$albumId/assets',
          ).replace(queryParameters: {'embed': 'asset'});
    final json = await _getJson(uri);
    return LightroomAssetPage(
      assets: [
        for (final resource in _resources(json))
          if (resource['asset'] is Map<String, Object?>)
            LightroomAsset.fromResource(
              resource['asset']! as Map<String, Object?>,
            ),
      ],
      nextUrl: _nextUrl(json),
    );
  }

  /// Raw rendition bytes. [size] is a Lightroom rendition type such as
  /// `2048` or `thumbnail2x`. Videos get poster-frame renditions.
  Future<Uint8List> getRendition({
    required String catalogId,
    required String assetId,
    required String size,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/v2/catalogs/$catalogId/assets/$assetId/renditions/$size',
    );
    final response = await _http.get(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFor(response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getAccessToken();
    final auth = await _auth.loadAuth();
    return {
      'Authorization': 'Bearer $token',
      'X-API-Key': auth?.clientId ?? '',
    };
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final response = await _http.get(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFor(response.statusCode);
    }
    final decoded = jsonDecode(stripAbuseGuard(response.body));
    if (decoded is! Map<String, Object?>) {
      throw const LightroomApiException(0, 'Unexpected Lightroom API response');
    }
    return decoded;
  }

  LightroomApiException _errorFor(int statusCode) {
    if (statusCode == 401) {
      return const LightroomApiException(
        401,
        'Adobe rejected the credentials. Reconnect Lightroom in Settings.',
      );
    }
    return LightroomApiException(statusCode, 'Lightroom API error $statusCode');
  }

  List<Map<String, Object?>> _resources(Map<String, Object?> json) {
    final raw = json['resources'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, Object?>>().toList();
  }

  String? _nextUrl(Map<String, Object?> json) {
    final links = json['links'];
    if (links is! Map<String, Object?>) return null;
    final next = links['next'];
    if (next is! Map<String, Object?>) return null;
    final href = next['href'];
    if (href is! String || href.isEmpty) return null;
    final uri = Uri.parse(href);
    return uri.hasScheme ? href : '$baseUrl$href';
  }

  /// Wall-clock timestamps formatted without a zone designator, matching
  /// how Lightroom reports capture dates.
  String? _isoWallClock(DateTime? t) {
    if (t == null) return null;
    return t.toIso8601String().replaceFirst('Z', '');
  }
}
