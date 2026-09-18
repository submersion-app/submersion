import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

/// Byte and metadata reads against the platform photo library, keyed by the
/// LOCAL asset id `AssetResolutionService` resolved.
///
/// Exists so the gallery resolver can run against a fake library in tests:
/// photo_manager has no test backend and `AssetEntity.fromId` answers null
/// under flutter_test, which looks exactly like a deleted photo.
abstract class GalleryAssetReader {
  Future<Uint8List?> originBytes(String assetId);
  Future<Uint8List?> thumbnailBytes(String assetId, int width, int height);
  Future<bool> exists(String assetId);
  Future<MediaSourceMetadata?> metadata(String assetId);
}

/// Production reader over photo_manager. Exercised on iOS, macOS and Android
/// hosts only.
// coverage:ignore-start
class PhotoManagerAssetReader implements GalleryAssetReader {
  const PhotoManagerAssetReader();

  @override
  Future<Uint8List?> originBytes(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.originBytes;
  }

  @override
  Future<Uint8List?> thumbnailBytes(
    String assetId,
    int width,
    int height,
  ) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(ThumbnailSize(width, height));
  }

  @override
  Future<bool> exists(String assetId) async =>
      await AssetEntity.fromId(assetId) != null;

  @override
  Future<MediaSourceMetadata?> metadata(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    final ll = await asset.latlngAsync();
    return MediaSourceMetadata(
      takenAt: asset.createDateTime,
      latitude: (ll?.latitude == 0.0) ? null : ll?.latitude,
      longitude: (ll?.longitude == 0.0) ? null : ll?.longitude,
      width: asset.width,
      height: asset.height,
      durationSeconds: asset.duration > 0 ? asset.duration : null,
      mimeType: asset.mimeType ?? 'application/octet-stream',
    );
  }
}
// coverage:ignore-end
