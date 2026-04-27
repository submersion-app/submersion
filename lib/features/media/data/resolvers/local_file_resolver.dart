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
///     bookmark keychain via [LocalBookmarkStorage], resolves the
///     security-scoped bookmark via [LocalMediaPlatform.resolveBookmark],
///     and returns [FileData] pointing at the resolved file. The caller is
///     responsible for releasing the security-scoped resource access via
///     [LocalMediaPlatform.releaseBookmark] when done. Display widgets
///     accept this responsibility implicitly by reading the bytes through
///     `Image.file` while the resource is still valid.
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
      try {
        final bytes = await _platform.readUriBytes(ref);
        return BytesData(bytes: bytes);
      } catch (_) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final blob = await _bookmarkStorage.read(ref);
      if (blob == null) {
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
      try {
        final resolved = await _platform.resolveBookmark(blob);
        return FileData(file: File(resolved.filePath));
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
