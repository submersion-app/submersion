import 'package:submersion/core/util/wall_clock_utc.dart';

/// The signed-in Adobe account, from GET /v2/account.
class LightroomAccount {
  const LightroomAccount({required this.id, this.fullName, this.email});

  final String id;
  final String? fullName;
  final String? email;
}

/// A Lightroom album (subtype `collection`).
class LightroomAlbum {
  const LightroomAlbum({required this.id, required this.name});

  final String id;
  final String name;
}

/// One catalog asset as returned by the assets endpoints. Parsing is
/// tolerant: any missing payload field becomes null rather than an error,
/// because the API omits blocks that do not apply to an asset.
class LightroomAsset {
  const LightroomAsset({
    required this.id,
    required this.subtype,
    this.captureDate,
    this.fileName,
    this.latitude,
    this.longitude,
    this.videoDurationSeconds,
  });

  final String id;
  final String subtype;

  /// Wall-clock UTC per the app-wide convention; null when Lightroom
  /// reports the unknown-capture-time sentinel (a `0000-...` date).
  final DateTime? captureDate;
  final String? fileName;
  final double? latitude;
  final double? longitude;
  final int? videoDurationSeconds;

  bool get isVideo => subtype == 'video';

  factory LightroomAsset.fromResource(Map<String, Object?> resource) {
    // Tolerant by design: the partner API varies asset shapes and has been
    // seen to return a list where a scalar is expected, so every field is
    // type-checked rather than cast -- an unchecked cast on a single odd
    // asset would abort an entire scan.
    final payload = _asMap(resource['payload']);
    final rawCapture = _asString(payload['captureDate']);
    DateTime? captureDate;
    if (rawCapture != null && !rawCapture.startsWith('0000')) {
      captureDate = parseExternalDateAsWallClockUtc(rawCapture);
    }
    final importSource = _asMap(payload['importSource']);
    final location = _asMap(payload['location']);
    final video = _asMap(payload['video']);
    return LightroomAsset(
      id: resource['id'] as String,
      subtype: _asString(resource['subtype']) ?? 'image',
      captureDate: captureDate,
      fileName: _asString(importSource['fileName']),
      latitude: _asDouble(location['latitude']),
      longitude: _asDouble(location['longitude']),
      videoDurationSeconds: _asInt(video['duration']),
    );
  }

  static Map<String, Object?> _asMap(Object? value) =>
      value is Map<String, Object?> ? value : const {};

  static String? _asString(Object? value) => value is String ? value : null;

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  static int? _asInt(Object? value) => value is num ? value.round() : null;
}

/// One page of an asset listing plus the absolute URL of the next page
/// (null on the last page).
class LightroomAssetPage {
  const LightroomAssetPage({required this.assets, this.nextUrl});

  final List<LightroomAsset> assets;
  final String? nextUrl;
}
