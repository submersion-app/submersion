import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/resolvers/media_fetch_gate.dart';
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

/// How long a mount-root probe is trusted before it is re-run (#1182).
///
/// Short because the cost of being wrong is a stale "volume offline" tile
/// after the user reconnects a share; long enough that one grid fling does
/// not re-probe. See [VolumeStatus.newExpiringProbe].
const Duration kVolumeProbeTtl = Duration(seconds: 5);

/// Ceiling on simultaneous local-file resolutions.
///
/// Higher than the media store's cap: a local stat is microseconds against a
/// healthy disk, so this is not a throughput throttle. It exists for the one
/// case the volume memo cannot cover -- a mount that is PRESENT but hung,
/// where the root probe succeeds and every per-file stat behind it still
/// parks a `dart:io` pool thread until the mount's own timeout.
const int kLocalResolveConcurrency = 8;

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
    Duration volumeProbeTtl = kVolumeProbeTtl,
    DateTime Function()? clock,
    MediaFetchGate? gate,
    bool Function()? usesSecurityScopedBookmarks,
  }) : _bookmarkStorage = bookmarkStorage,
       _platform = platform,
       _exifExtractor = exifExtractor,
       _videoThumbnails = videoThumbnails,
       _volumeOnline = (volumeStatus ?? VolumeStatus()).newExpiringProbe(
         ttl: volumeProbeTtl,
         clock: clock,
       ),
       _gate = gate ?? MediaFetchGate(maxConcurrent: kLocalResolveConcurrency),
       _usesSecurityScopedBookmarks =
           usesSecurityScopedBookmarks ??
           (() => Platform.isIOS || Platform.isMacOS);

  final VideoThumbnailService? _videoThumbnails;

  /// Whether the volume under a path is mounted, memoized per mount root for
  /// [kVolumeProbeTtl].
  ///
  /// This resolver is a long-lived singleton and the highest-volume caller of
  /// the probe there is: one call per grid tile, and a 140 px grid puts 30-60
  /// tiles on screen on desktop. Un-memoized, a library on one unreachable
  /// share paid that share's stat timeout once per tile.
  ///
  /// A path on the system volume short-circuits inside the probe before any
  /// filesystem call, so an all-internal-disk library pays nothing.
  final Future<bool> Function(String path) _volumeOnline;

  /// Caps simultaneous resolutions and shares one in flight between rows
  /// pointing at the same file. Its own instance rather than the media
  /// store's: a dead mount must not consume the budget the gallery needs for
  /// store fetches.
  final MediaFetchGate _gate;

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

  /// Coalescing key: rows are reference-linked, so the same photo attached to
  /// two dives is two rows pointing at one file. Sharing one in-flight
  /// resolution between them saves a stat per row on the same file.
  ///
  /// Keyed on BOTH pointers, not just the path. [_resolveInner] falls through
  /// from the path to the bookmark, so two rows with a common path but
  /// different bookmarks do not have the same answer -- keying on the path
  /// alone would hand the second row the first row's bytes whenever the path
  /// failed. Rows that share a key share every input that resolution reads.
  ///
  /// Falls back to the row id when neither pointer is set, so rows that
  /// cannot resolve anything never share one another's result.
  static String _gateKey(MediaItem item) {
    final path = item.localPath ?? item.filePath ?? '';
    final ref = item.bookmarkRef ?? '';
    if (path.isEmpty && ref.isEmpty) return item.id;
    // NUL separator: it cannot occur in a filesystem path or a keychain
    // ref, so no (path, ref) pair can collide with a different pair.
    return '$path\u0000$ref';
  }

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final data = await _gate.run(_gateKey(item), () => _resolveInner(item));
    // [MediaFetchGate]'s payload is nullable for the media store, where null
    // means "not in the store". _resolveInner is declared non-nullable and
    // always answers, so this fallback cannot be reached; it is written as a
    // total function rather than a `!` so a future change cannot turn a
    // resolver bug into a crash on a grid tile.
    return data ?? const UnavailableData(kind: UnavailableKind.notFound);
  }

  Future<MediaSourceData> _resolveInner(MediaItem item) async {
    // Desktop path: localPath set, no bookmark needed.
    final localPath = item.localPath ?? item.filePath;
    if (localPath != null && localPath.isNotEmpty) {
      // Ask whether the volume is even mounted BEFORE touching the file
      // (#1182). The check used to sit after the exists() below, which meant
      // a library on a dead share paid a per-tile stat against that share --
      // each one parking a `dart:io` pool thread until the mount timed out --
      // and only then consulted a probe that could have answered for free.
      // Both databases run on this isolate with a synchronous
      // NativeDatabase, so starving that pool stalls SQLite too, which is how
      // a thumbnail problem became an app-wide freeze.
      //
      // Costs nothing for a path on the system volume: the probe resolves
      // those without a filesystem call at all.
      if (!await _volumeOnlineOrAssumed(localPath)) {
        return const UnavailableData(kind: UnavailableKind.volumeOffline);
      }
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
          if (blocker == null) {
            return FileData(file: f, servedFrom: ServedFrom.localDisk);
          }
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
        if (!await _volumeOnlineOrAssumed(localPath)) {
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
        if (!await _volumeOnlineOrAssumed(localPath)) {
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
        return BytesData(bytes: bytes, servedFrom: ServedFrom.localDisk);
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
        return BytesData(bytes: bytes, servedFrom: ServedFrom.localDisk);
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

  /// [_volumeOnline], with a probe that itself failed treated as online.
  ///
  /// The probe is a filesystem call and can throw on the exact mounts it
  /// exists to classify. Reporting volumeOffline on a throw would be a guess;
  /// assuming online falls through to the file itself, which is what this
  /// resolver did before the probe was hoisted ahead of it, and lets the
  /// existing exists() / open() path produce the real answer.
  Future<bool> _volumeOnlineOrAssumed(String path) async {
    try {
      return await _volumeOnline(path);
    } on FileSystemException catch (e) {
      _log.debug('Volume probe failed for $path; assuming online', error: e);
      return true;
    }
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
      if (poster != null) {
        return BytesData(
          bytes: poster,
          servedFrom: ServedFrom.localDisk,
          servedTier: ServedTier.thumbnail,
        );
      }
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
    // "Still fetching" is a statement about time, not about whether the file
    // is there: the read outlived the gate's budget and is very likely still
    // running. Falling through would put a hung-but-mounted share on the
    // notFound path below, and notFound flips isOrphaned, so a share that was
    // merely slow during a sweep would mark its whole library missing.
    if (data.kind == UnavailableKind.stillFetching) {
      return VerifyResult.transientError;
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
