import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Thin seam over the iCloud container so the media adapter is testable
/// against a temp directory. The default implementation delegates to
/// ICloudNativeService statics plus dart:io.
abstract class ICloudMediaPlatform {
  /// The container's Documents directory, or null when iCloud is
  /// unavailable on this device/build.
  Future<String?> containerPath();

  /// Coordinated small-file write.
  Future<void> writeSmallFile(String path, Uint8List data);

  /// Coordinated move of a local file into the container (large files;
  /// the OS uploads in the background).
  Future<bool> moveIntoContainer(String sourcePath, String destinationPath);

  /// Ensures the file at [path] is materialized locally.
  Future<bool> ensureDownloaded(String path);

  /// Best-effort refresh so files from other devices become visible.
  Future<void> refreshFolder(String path);
}

/// Production implementation over the native channel.
class NativeICloudMediaPlatform implements ICloudMediaPlatform {
  @override
  Future<String?> containerPath() => ICloudNativeService.getContainerPath();

  @override
  Future<void> writeSmallFile(String path, Uint8List data) async {
    try {
      await ICloudNativeService.writeFile(path, data);
    } on Exception catch (e) {
      throw MediaStoreException(
        'iCloud write failed for $path',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
  }

  @override
  Future<bool> moveIntoContainer(String sourcePath, String destinationPath) =>
      ICloudNativeService.moveFile(sourcePath, destinationPath);

  @override
  Future<bool> ensureDownloaded(String path) =>
      ICloudNativeService.downloadIfNeeded(path);

  @override
  Future<void> refreshFolder(String path) =>
      ICloudNativeService.refreshFolder(path);
}

/// Temp-directory fake for tests: the "container" is a plain directory.
class DirectoryICloudMediaPlatform implements ICloudMediaPlatform {
  DirectoryICloudMediaPlatform(this.root);

  final Directory root;

  @override
  Future<String?> containerPath() async => root.path;

  @override
  Future<void> writeSmallFile(String path, Uint8List data) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data, flush: true);
  }

  @override
  Future<bool> moveIntoContainer(
    String sourcePath,
    String destinationPath,
  ) async {
    final source = File(sourcePath);
    if (!await source.exists()) return false;
    await File(destinationPath).parent.create(recursive: true);
    try {
      await source.rename(destinationPath);
    } on FileSystemException {
      await source.copy(destinationPath);
      await source.delete();
    }
    return true;
  }

  @override
  Future<bool> ensureDownloaded(String path) => File(path).exists();

  @override
  Future<void> refreshFolder(String path) async {}
}
