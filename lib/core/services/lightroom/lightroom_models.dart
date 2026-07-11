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
    final payload = resource['payload'] as Map<String, Object?>? ?? const {};
    final rawCapture = payload['captureDate'] as String?;
    DateTime? captureDate;
    if (rawCapture != null && !rawCapture.startsWith('0000')) {
      captureDate = parseExternalDateAsWallClockUtc(rawCapture);
    }
    final importSource =
        payload['importSource'] as Map<String, Object?>? ?? const {};
    final location = payload['location'] as Map<String, Object?>? ?? const {};
    final video = payload['video'] as Map<String, Object?>? ?? const {};
    return LightroomAsset(
      id: resource['id'] as String,
      subtype: resource['subtype'] as String? ?? 'image',
      captureDate: captureDate,
      fileName: importSource['fileName'] as String?,
      latitude: (location['latitude'] as num?)?.toDouble(),
      longitude: (location['longitude'] as num?)?.toDouble(),
      videoDurationSeconds: (video['duration'] as num?)?.round(),
    );
  }
}

/// One page of an asset listing plus the absolute URL of the next page
/// (null on the last page).
class LightroomAssetPage {
  const LightroomAssetPage({required this.assets, this.nextUrl});

  final List<LightroomAsset> assets;
  final String? nextUrl;
}
