import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// iCloud-backed media object store (design spec section 8.2). Keys map to
/// `<container>/[rootFolder]/<key>`; the ubiquity container behaves as a
/// coordinated filesystem, so small objects write directly and large ones
/// move in via native file coordination. Upload/download resume and
/// progress are OS-managed: the adapter accepts the resume parameters and
/// reports a single completion tick.
class ICloudMediaObjectStore implements MediaObjectStore {
  ICloudMediaObjectStore({
    required ICloudMediaPlatform platform,
    this.rootFolder = 'submersion-media',
    this.smallFileThresholdBytes = 8 * 1024 * 1024,
  }) : _platform = platform;

  final ICloudMediaPlatform _platform;
  final String rootFolder;
  final int smallFileThresholdBytes;

  Future<String> _root() async {
    final container = await _platform.containerPath();
    if (container == null) {
      throw const MediaStoreException(
        'iCloud is not available on this device',
        kind: MediaStoreErrorKind.fatal,
      );
    }
    return p.join(container, rootFolder);
  }

  Future<String> _pathFor(String key) async => p.join(await _root(), key);

  @override
  Future<StoreObjectInfo?> head(String key) async {
    final path = await _pathFor(key);
    if (!await _platform.ensureDownloaded(path)) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    return StoreObjectInfo(
      key: key,
      sizeBytes: stat.size,
      lastModified: stat.modified,
    );
  }

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) async {
    final path = await _pathFor(key);
    final int length;
    try {
      length = await source.length();
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
    await Directory(p.dirname(path)).create(recursive: true);
    if (length <= smallFileThresholdBytes) {
      await _platform.writeSmallFile(path, await source.readAsBytes());
    } else {
      // Copy to a container-local sibling first so the coordinated move is
      // same-volume, then let the OS upload in the background.
      final staging = '$path.uploading';
      await source.copy(staging);
      final moved = await _platform.moveIntoContainer(staging, path);
      if (!moved) {
        throw MediaStoreException(
          'iCloud move failed for $key',
          kind: MediaStoreErrorKind.transient,
        );
      }
    }
    onProgress?.call(length, length);
  }

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    final path = await _pathFor(key);
    if (!await _platform.ensureDownloaded(path)) {
      throw MediaStoreException(
        'not found: $key',
        kind: MediaStoreErrorKind.notFound,
      );
    }
    final file = File(path);
    if (!await file.exists()) {
      throw MediaStoreException(
        'not found: $key',
        kind: MediaStoreErrorKind.notFound,
      );
    }
    await file.copy(destination.path);
    final length = await destination.length();
    onProgress?.call(length, length);
  }

  @override
  Future<void> delete(String key) async {
    final path = await _pathFor(key);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> abandonResume(String key, String? resumeStateJson) async {
    // Upload sessions are OS-managed; nothing to abort.
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final root = await _root();
    await _platform.refreshFolder(root);
    final directory = Directory(root);
    if (!await directory.exists()) return;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final key = p
          .relative(entity.path, from: root)
          .replaceAll(p.separator, '/');
      if (!key.startsWith(keyPrefix)) continue;
      if (key.endsWith('.uploading')) continue;
      final stat = await entity.stat();
      yield StoreObjectInfo(
        key: key,
        sizeBytes: stat.size,
        lastModified: stat.modified,
      );
    }
  }
}
