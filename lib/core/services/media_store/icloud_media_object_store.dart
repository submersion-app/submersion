import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/storage/scratch_sweep.dart';

/// iCloud-backed media object store (design spec section 8.2). Keys map to
/// `<container>/[rootFolder]/<key>`; the ubiquity container behaves as a
/// coordinated filesystem, so small objects write directly and large ones
/// move in via native file coordination. Upload/download resume and
/// progress are OS-managed: the adapter accepts the resume parameters and
/// reports a single completion tick.
class ICloudMediaObjectStore implements MediaObjectStore, LocalListingStore {
  ICloudMediaObjectStore({
    required ICloudMediaPlatform platform,
    this.rootFolder = 'submersion-media',
    this.smallFileThresholdBytes = 8 * 1024 * 1024,
    Future<void> Function(File file, DateTime at)? dateStagedCopy,
  }) : _platform = platform,
       _dateStagedCopy = dateStagedCopy ?? _setLastModified;

  static Future<void> _setLastModified(File file, DateTime at) =>
      file.setLastModified(at);

  final ICloudMediaPlatform _platform;
  final Future<void> Function(File file, DateTime at) _dateStagedCopy;
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
    // Same distinction getFile draws below, and it matters more here: null
    // means "not in the store" to every caller, and the upload pipeline
    // answers that by uploading. Reporting a placeholder still coming down
    // as absent re-uploads the whole library from the second device, and
    // lets the dedup stamp fall back to this device's local byte count.
    if (!await _platform.ensureDownloaded(path)) {
      throw MediaStoreException(
        'still downloading from iCloud: $key',
        kind: MediaStoreErrorKind.transient,
      );
    }
    final file = File(path);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    return StoreObjectInfo(
      key: key,
      sizeBytes: stat.size,
      lastModified: lastTouched(stat),
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
      // File.copy keeps the source's modification time on Apple platforms,
      // and list() reports that time: a fresh upload of an old video would
      // look months old to the storage cleanup, whose grace window runs from
      // lastModified. Date the object by the upload instead, or do not
      // publish it: the retry dates it again.
      try {
        await _dateStagedCopy(File(staging), DateTime.now());
      } on FileSystemException catch (e) {
        try {
          await File(staging).delete();
        } on FileSystemException catch (_) {
          // A leftover is hidden from list(), and the retry's copy
          // replaces it.
        }
        throw MediaStoreException(
          'Could not date the staged upload for $key',
          kind: MediaStoreErrorKind.transient,
          cause: e,
        );
      }
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
    // A false answer means iCloud KNOWS the file: the placeholder is on disk,
    // startDownloadingUbiquitousItem succeeded, and the native poll ran out
    // waiting for the bytes. A key the container has never held does not get
    // here (the native side answers true for a non-ubiquitous path and the
    // exists() check below reports it absent). Reporting the slow download
    // as notFound made StoreMarkerStore.ensure mint a fresh store id over a
    // marker another device had already written (issue #1356).
    if (!await _platform.ensureDownloaded(path)) {
      throw MediaStoreException(
        'still downloading from iCloud: $key',
        kind: MediaStoreErrorKind.transient,
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
      return;
    }
    // Evicted: the object is only its `.<name>.icloud` placeholder here.
    final placeholder = File(
      p.join(p.dirname(path), '.${p.basename(path)}.icloud'),
    );
    if (await placeholder.exists()) await placeholder.delete();
  }

  @override
  Future<void> abandonResume(String key, String? resumeStateJson) async {
    // Upload sessions are OS-managed; nothing to abort.
  }

  @override
  Future<int> reapStaleUploadSessions({required DateTime olderThan}) async {
    // Upload sessions are OS-managed; nothing to reap.
    return 0;
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final root = await _root();
    await _platform.refreshFolder(root);
    yield* _walk(root, keyPrefix);
  }

  /// The container as this device has it, without the refresh [list] runs:
  /// that refresh starts downloading every evicted item.
  @override
  Stream<StoreObjectInfo> listLocal(String keyPrefix) async* {
    yield* _walk(await _root(), keyPrefix);
  }

  /// Both listings report an evicted item (a `.<name>.icloud` placeholder)
  /// under its own key with no size: the refresh only starts downloads, and
  /// a sweep that saw the placeholder's name would take a present object
  /// for a missing one. Ages are the later of modification and change
  /// time: older builds staged uploads with the source's modification time,
  /// while the change time says when the file arrived here.
  Stream<StoreObjectInfo> _walk(String root, String keyPrefix) async* {
    final directory = Directory(root);
    if (!await directory.exists()) return;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      var key = p
          .relative(entity.path, from: root)
          .replaceAll(p.separator, '/');
      final placeholder = _placeholderKey(key);
      if (placeholder != null) key = placeholder;
      if (!key.startsWith(keyPrefix)) continue;
      if (key.endsWith('.uploading')) continue;
      final stat = await entity.stat();
      yield StoreObjectInfo(
        key: key,
        sizeBytes: placeholder == null ? stat.size : null,
        lastModified: lastTouched(stat),
      );
    }
  }

  /// `dir/.name.icloud` -> `dir/name`, or null for any other key.
  static String? _placeholderKey(String key) {
    final slash = key.lastIndexOf('/');
    final name = key.substring(slash + 1);
    if (!name.startsWith('.') || !name.endsWith('.icloud')) return null;
    final real = name.substring(1, name.length - '.icloud'.length);
    if (real.isEmpty) return null;
    return '${key.substring(0, slash + 1)}$real';
  }
}
