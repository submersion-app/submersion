import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Byte reads and existence checks against the platform photo library, keyed
/// by the LOCAL asset id `AssetResolutionService` resolved.
///
/// Exists so the gallery resolver can run against a fake library in tests:
/// photo_manager has no test backend and `AssetEntity.fromId` answers null
/// under flutter_test, which looks exactly like a deleted photo.
abstract class GalleryAssetReader {
  Future<Uint8List?> originBytes(String assetId);

  /// Whether this platform keeps originals as files, so [originFile] is how
  /// to read one and [originBytes] would be the same file read into memory.
  ///
  /// Files are preferred wherever the platform keeps them (issue #4699):
  /// bytes put the whole original in memory, which for a 4K video is
  /// hundreds of MB, while a file is read or copied a piece at a time.
  bool get originalsAsFiles;

  /// The original as the file the platform keeps, or null when it cannot be
  /// had. Asked only where [originalsAsFiles] holds.
  Future<File?> originFile(String assetId);
  Future<Uint8List?> thumbnailBytes(String assetId, int width, int height);
  Future<bool> exists(String assetId);

  /// Whether the library holds [assetId]'s original on this device, rather
  /// than only in iCloud, where reading it means a download (issue #4727).
  /// False for an asset not found.
  Future<bool> originIsLocal(String assetId);
}

/// Asset [assetId]'s original through [reader]: the file the library keeps
/// where it keeps one, else its bytes, or null when it cannot be read.
///
/// The one place that chooses between the two, so every reader of an
/// original (the gallery resolver, the library search) holds to
/// [GalleryAssetReader.originalsAsFiles]. Never both: where originals are
/// files the bytes are that file read back, so a failed export would only
/// be tried again.
Future<MediaSourceData?> readGalleryOriginal(
  GalleryAssetReader reader,
  String assetId,
) async {
  if (reader.originalsAsFiles) {
    final file = await reader.originFile(assetId);
    if (file == null) return null;
    return FileData(file: file, servedFrom: ServedFrom.platformGallery);
  }
  final bytes = await reader.originBytes(assetId);
  if (bytes == null) return null;
  return BytesData(bytes: bytes, servedFrom: ServedFrom.platformGallery);
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

  /// Files on every platform photo_manager serves (Apple platforms and
  /// Android; it reads nothing elsewhere, either way).
  ///
  /// On iOS and macOS photo_manager reads an original by exporting it to a
  /// file and reading that back, and it reuses the export while it lasts, so
  /// handing over the file costs nothing more.
  ///
  /// On Android the bytes are the whole original read into one array, copied
  /// again into the platform channel and once more into Dart. A dive video
  /// read that way ran the app out of memory while staging its upload, and
  /// photo_manager's catch does not reach an OutOfMemoryError, so the app
  /// died at every launch that resumed the upload (issue #4999). Its file
  /// read streams the original into the app's cache instead, the same cache
  /// the video player already reads from.
  @override
  bool get originalsAsFiles => true;

  @override
  Future<File?> originFile(String assetId) async {
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

  @override
  Future<bool> originIsLocal(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    return asset != null && await asset.isLocallyAvailable(isOrigin: true);
  }
}
// coverage:ignore-end
