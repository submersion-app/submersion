import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/core/platform/host_platform.dart';

/// Byte reads and existence checks against the platform photo library, keyed
/// by the LOCAL asset id `AssetResolutionService` resolved.
///
/// Exists so the gallery resolver can run against a fake library in tests:
/// photo_manager has no test backend and `AssetEntity.fromId` answers null
/// under flutter_test, which looks exactly like a deleted photo.
abstract class GalleryAssetReader {
  Future<Uint8List?> originBytes(String assetId);

  /// The original as a file the platform already keeps, or null where it
  /// has none to share and [originBytes] is the way to read it.
  ///
  /// Preferred over [originBytes] wherever it answers (issue #4699): bytes
  /// put the whole original in memory, which for a 4K video is hundreds of
  /// MB, while a file is read or copied a piece at a time.
  Future<File?> originFile(String assetId);
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

  /// On iOS and macOS photo_manager reads an original by exporting it to a
  /// file and reading that back, and it reuses the export while it lasts, so
  /// handing over the file costs nothing more. On Android the bytes cross
  /// the platform channel instead, and a file would be a new copy on disk.
  @override
  Future<File?> originFile(String assetId) async {
    if (!HostPlatform.isApple) return null;
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.originFile;
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
