import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.localFile] items across all platforms.
///
/// Per-platform behavior:
///   * Desktop (macOS native, Windows, Linux): reads [MediaItem.localPath]
///     directly via dart:io and returns [FileData].
///   * iOS / macOS (sandboxed): reads [MediaItem.bookmarkRef] from the
///     bookmark keychain via [LocalBookmarkStorage], reads the file bytes
///     via [LocalMediaPlatform.readBookmarkBytes] (which manages the
///     security-scoped resource lifecycle natively — start access, read,
///     release on the same call), and returns [BytesData]. Returning
///     [BytesData] here (rather than [FileData] from a resolved bookmark
///     handle) keeps the security-scope ownership self-contained and
///     avoids leaking native handles when callers forget to release them.
///   * Android: reads [MediaItem.bookmarkRef] as a content URI string,
///     calls [LocalMediaPlatform.readUriBytes], and returns [BytesData].
///
/// The Phase 1 stub fell back to [UnavailableData] on iOS / Android; this
/// promotion replaces that with the full bookmark / URI flow.
class LocalFileResolver implements MediaSourceResolver {
  final LocalBookmarkStorage _bookmarkStorage;
  final LocalMediaPlatform _platform;
  final ExifExtractor _exifExtractor;

  LocalFileResolver({
    required LocalBookmarkStorage bookmarkStorage,
    required LocalMediaPlatform platform,
    required ExifExtractor exifExtractor,
  }) : _bookmarkStorage = bookmarkStorage,
       _platform = platform,
       _exifExtractor = exifExtractor;

  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) {
    // Device-local pointers don't cross machines.
    return true;
  }

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    // Desktop path: localPath set, no bookmark needed.
    final localPath = item.localPath ?? item.filePath;
    if (localPath != null && localPath.isNotEmpty) {
      try {
        final f = File(localPath);
        if (await f.exists()) return FileData(file: f);
      } on FileSystemException {
        // Fall through to bookmark path or unavailable.
      }
    }

    final ref = item.bookmarkRef;
    if (ref == null || ref.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }

    if (Platform.isAndroid) {
      // coverage:ignore-start
      // Android-only URI-bytes branch; test suite runs on macOS hosts so the
      // `if` evaluates false. Behaviour mirrored by the iOS/macOS
      // bookmark-bytes branch below, which is unit-tested.
      try {
        final bytes = await _platform.readUriBytes(ref);
        return BytesData(bytes: bytes);
      } catch (_) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
      // coverage:ignore-end
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final blob = await _bookmarkStorage.read(ref);
      if (blob == null) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
      try {
        // readBookmarkBytes is self-contained on the native side: it starts
        // security-scoped resource access, reads the file, and releases
        // access in a single call. Returning BytesData here (instead of
        // FileData from a resolved bookmark handle) avoids leaking the
        // security scope when callers forget to invoke releaseBookmark.
        final bytes = await _platform.readBookmarkBytes(blob);
        return BytesData(bytes: bytes);
      } catch (_) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
    }

    return const UnavailableData(kind: UnavailableKind.notFound);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async {
    final data = await resolve(item);
    if (data is FileData) {
      return _exifExtractor.extract(data.file);
    }
    if (data is BytesData) {
      // Android: write bytes to a temp file, run extractor, delete.
      final tmp = File('${Directory.systemTemp.path}/exif_${item.id}.bin');
      try {
        await tmp.writeAsBytes(data.bytes);
        return await _exifExtractor.extract(tmp);
      } finally {
        if (await tmp.exists()) {
          try {
            await tmp.delete();
          } on FileSystemException {
            // Best-effort cleanup.
          }
        }
      }
    }
    return null;
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final data = await resolve(item);
    return data is UnavailableData
        ? VerifyResult.notFound
        : VerifyResult.available;
  }
}
