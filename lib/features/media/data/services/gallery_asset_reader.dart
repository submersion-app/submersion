import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

/// Byte reads and existence checks against the platform photo library, keyed
/// by the LOCAL asset id `AssetResolutionService` resolved.
///
/// Exists so the gallery resolver can run against a fake library in tests:
/// photo_manager has no test backend and `AssetEntity.fromId` answers null
/// under flutter_test, which looks exactly like a deleted photo.
abstract class GalleryAssetReader {
  Future<Uint8List?> originBytes(String assetId);
  Future<Uint8List?> thumbnailBytes(String assetId, int width, int height);
  Future<bool> exists(String assetId);
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
}
// coverage:ignore-end
