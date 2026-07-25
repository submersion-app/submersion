import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/video_thumbnail_service.dart';
import 'package:submersion/features/media/data/services/volume_status.dart';
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
    VideoThumbnailService? videoThumbnails,
    VolumeStatus? volumeStatus,
    bool Function()? usesSecurityScopedBookmarks,
  }) : _bookmarkStorage = bookmarkStorage,
       _platform = platform,
       _exifExtractor = exifExtractor,
       _videoThumbnails = videoThumbnails,
       _volumeStatus = volumeStatus ?? VolumeStatus(),
       _usesSecurityScopedBookmarks =
           usesSecurityScopedBookmarks ??
           (() => Platform.isIOS || Platform.isMacOS);

  final VideoThumbnailService? _videoThumbnails;
  final VolumeStatus _volumeStatus;

  /// Whether this host resolves local files through security-scoped
  /// bookmarks (iOS / macOS) rather than a plain path.
  ///
  /// Injectable for the same reason [VolumeStatus.directoryExists] is: the
  /// unit shards run on Linux, so a hard `Platform.isMacOS` check would
  /// leave the bookmark branch — the only path that can resolve a sandboxed
  /// file, and the whole point of this resolver on Apple platforms —
  /// unexecuted in CI. Production always gets the real check.
  final bool Function() _usesSecurityScopedBookmarks;
  final _log = LoggerService.forClass(LocalFileResolver);

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
        // Existence alone is not enough: the macOS sandbox allows STAT on
        // user files (~/Downloads etc.) while denying OPEN, so exists()
        // returns true for a file Image.file can never actually read
        // (PathAccessException, EPERM). Probe readability and fall through
        // to the security-scoped bookmark — the design's source of truth
        // on macOS — when the direct read is denied.
        if (await f.exists()) {
          final blocker = await _readBlocker(f);
          if (blocker == null) return FileData(file: f);
          _log.debug(
            'localPath exists but cannot be opened (sandbox?), falling '
            'back to bookmark: $localPath [item ${item.id}]',
            error: blocker,
          );
        } else {
          _log.debug(
            'localPath does not exist, falling back to bookmark: '
            '$localPath [item ${item.id}]',
          );
        }
        // Missing file on an unmounted volume (network share, external
        // disk) is a temporary condition, not a dead pointer: report it
        // as such so nothing orphans the row while the share is offline.
        if (!await _volumeStatus.isVolumeOnline(localPath)) {
          return const UnavailableData(kind: UnavailableKind.volumeOffline);
        }
      }
      // coverage:ignore-start
      // FileSystemException from File.exists() requires a permission /
      // filesystem error that flutter_test's tmpdir-based fixtures don't
      // produce. Fallback path to bookmark / Unavailable is exercised by
      // tests above.
      on FileSystemException {
        // Offline network mounts commonly THROW here rather than return
        // false; an offline volume must still read volumeOffline, not
        // fall through to a hard notFound (which cleanup could orphan).
        if (!await _volumeStatus.isVolumeOnline(localPath)) {
          return const UnavailableData(kind: UnavailableKind.volumeOffline);
        }
        // Otherwise fall through to bookmark path or unavailable.
      }
      // coverage:ignore-end
    }

    final ref = item.bookmarkRef;
    if (ref == null || ref.isEmpty) {
      _log.warning(
        'No usable localPath and no bookmarkRef; item ${item.id} '
        'is unresolvable on this device',
      );
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
      } catch (e, st) {
        _log.warning(
          'readUriBytes failed for item ${item.id}',
          error: e,
          stackTrace: st,
        );
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
      // coverage:ignore-end
    }

    if (_usesSecurityScopedBookmarks()) {
      final blob = await _bookmarkStorage.read(ref);
      if (blob == null) {
        _log.warning(
          'Bookmark blob $ref missing from secure storage for '
          'item ${item.id}',
        );
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
      } catch (e, st) {
        _log.warning(
          'readBookmarkBytes failed for item ${item.id}',
          error: e,
          stackTrace: st,
        );
        return const UnavailableData(kind: UnavailableKind.notFound);
      }
    }

    return const UnavailableData(kind: UnavailableKind.notFound);
  }

  /// Returns null when [f] can actually be opened for reading, otherwise the
  /// exception that blocked it. Complements the exists() check in [resolve]:
  /// a sandboxed build can stat a user file it is not allowed to open, and
  /// handing such a file to Image.file produces a broken tile with no
  /// diagnosable error. An open/close round-trip is cheap relative to
  /// decoding and runs only on the localFile resolve path.
  ///
  /// The exception is returned rather than collapsed to a bool so the caller
  /// can log the concrete reason (EPERM vs. ENOENT vs. an I/O error) — the
  /// whole point of this path is that the failure was previously invisible.
  Future<FileSystemException?> _readBlocker(File f) async {
    try {
      final raf = await f.open();
      await raf.close();
      return null;
    } on FileSystemException catch (e) {
      return e;
    }
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    // Videos cannot be decoded as images; ask the OS for a poster frame and
    // return it as bytes. On any failure fall back to the raw-video FileData,
    // which MediaItemView renders as the movie-icon placeholder.
    //
    // Desktop-gated on purpose: native handlers exist only for macOS, Windows
    // and Linux, so on mobile the channel call could only ever end in a
    // MissingPluginException -> null. Locally-imported mobile media exits
    // posterFor immediately anyway (iOS and Android both leave localPath null
    // and key off a bookmark / content URI), but a row synced from a desktop
    // device carries a localPath that means nothing here - without this gate
    // that row would pay a stat, a cache lookup and a channel round-trip per
    // render to reach the placeholder it was always going to show. The gate
    // also puts the spec's desktop-only scope in the code rather than leaving
    // it implied.
    if (item.isVideo &&
        _videoThumbnails != null &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final maxDim = target.longestSide.round().clamp(1, 4096);
      final poster = await _videoThumbnails.posterFor(
        item,
        maxDimension: maxDim,
      );
      if (poster != null) return BytesData(bytes: poster);
    }
    return resolve(item);
  }

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
          }
          // coverage:ignore-start
          // FileSystemException on a tmpdir delete is not produced by
          // flutter_test fixtures; cleanup is best-effort either way.
          on FileSystemException {
            // Best-effort cleanup.
          }
          // coverage:ignore-end
        }
      }
    }
    return null;
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final data = await resolve(item);
    if (data is! UnavailableData) return VerifyResult.available;
    if (data.kind == UnavailableKind.volumeOffline) {
      return VerifyResult.volumeOffline;
    }
    // A file that is present but unreadable (sandbox denial, revoked
    // permission) is not a dead pointer: the bytes are still on disk and a
    // re-grant restores access. Reporting notFound here would let the
    // re-verify sweep flag the row "missing from device", which is both
    // wrong and sticky. transientError updates lastVerifiedAt without
    // touching the orphan flag.
    final localPath = item.localPath ?? item.filePath;
    if (localPath != null && localPath.isNotEmpty) {
      try {
        if (await File(localPath).exists()) return VerifyResult.transientError;
      }
      // coverage:ignore-start
      // Only reachable when exists() itself throws (permission/FS error),
      // which flutter_test's tmpdir fixtures do not produce. Falling through
      // to notFound matches the pre-existing behaviour.
      on FileSystemException {
        // Fall through to notFound.
      }
      // coverage:ignore-end
    }
    return VerifyResult.notFound;
  }
}
