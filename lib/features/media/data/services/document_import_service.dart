import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// How a host makes a picked document re-openable after the app restarts.
enum DocumentRefStrategy {
  /// iOS: security-scoped bookmark only. The picker path is sandbox-scoped
  /// and worthless once the pick is over, so it is not recorded.
  bookmark,

  /// macOS: bookmark plus the path, which the desktop UI needs for
  /// "Show in Finder". The bookmark stays the source of truth.
  bookmarkWithPath,

  /// Android: persisted SAF content URI, falling back to the picked path
  /// when the pick carried no content URI or the provider refused a
  /// persistable grant.
  persistableUri,

  /// Windows / Linux: the picked path is itself durable.
  plainPath,
}

/// Links picked document files (PDFs and common formats) to a dive or a
/// site by reference: security-scoped bookmark on iOS/macOS, persisted SAF
/// URI on Android, plain path on Windows/Linux. Never copies bytes; the
/// media store upload (enqueued via [onMediaCreated]) is the durability
/// path.
///
/// Unlike FilesTabNotifier, this is the one importer that can take an
/// Android persistable URI: its picker asks for [allowedExtensions], which
/// routes file_picker to `ACTION_OPEN_DOCUMENT` and therefore to a grant
/// worth persisting. That grant is not guaranteed, though — a provider may
/// refuse it — so an Android row carries EITHER a `bookmarkRef` or a
/// `localPath`, never reliably the former. Read them the way
/// `LocalFileResolver` does: path first, bookmark second. See
/// [DocumentRefStrategy.persistableUri].
class DocumentImportService {
  DocumentImportService({
    required this.mediaRepository,
    required this.platform,
    required this.bookmarkStorage,
    this.onMediaCreated,
    DocumentRefStrategy Function()? refStrategy,
  }) : _refStrategy = refStrategy ?? hostRefStrategy;

  final MediaRepository mediaRepository;
  final LocalMediaPlatform platform;
  final LocalBookmarkStorage bookmarkStorage;

  /// Invoked after every successful createMedia so the media store can
  /// enqueue an upload. Null when no store is configured.
  final void Function(String mediaId)? onMediaCreated;

  /// Which reference strategy to apply. Injectable for the same reason
  /// `LocalFileResolver._usesSecurityScopedBookmarks` is: the unit shards
  /// run on macOS / Linux, so a hard `Platform.isAndroid` check would leave
  /// the Android branch — the one issue #1002 was filed against —
  /// unexecuted in CI. Production always gets [hostRefStrategy].
  final DocumentRefStrategy Function() _refStrategy;

  /// The real per-platform strategy.
  static DocumentRefStrategy hostRefStrategy() {
    if (Platform.isIOS) return DocumentRefStrategy.bookmark;
    if (Platform.isMacOS) return DocumentRefStrategy.bookmarkWithPath;
    if (Platform.isAndroid) return DocumentRefStrategy.persistableUri;
    return DocumentRefStrategy.plainPath;
  }

  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DocumentImportService);

  /// Formats offered by the document picker. `pdf` renders in-app; the
  /// rest are opaque attachments that open externally.
  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'gpx',
  ];

  /// Persists each picked file as a `document` media row linked to exactly
  /// one of [diveId] / [siteId]. Returns the created rows.
  ///
  /// [picked] carries both halves of a `PlatformFile`: `path` is the local
  /// file the picker produced, and `identifier` is the platform's own
  /// handle for the original (an Android SAF content URI; null elsewhere).
  /// They are not interchangeable — see the Android branch below.
  Future<List<MediaItem>> importDocuments({
    required List<({String path, String filename, String? identifier})> picked,
    String? diveId,
    String? siteId,
  }) async {
    assert(
      (diveId == null) != (siteId == null),
      'exactly one of diveId/siteId must be set',
    );
    final strategy = _refStrategy();
    final created = <MediaItem>[];
    for (final file in picked) {
      String? localPath;
      String? bookmarkRef;

      switch (strategy) {
        case DocumentRefStrategy.bookmark:
        case DocumentRefStrategy.bookmarkWithPath:
          final blob = await platform.createBookmark(file.path);
          bookmarkRef = _uuid.v4();
          await bookmarkStorage.write(bookmarkRef, blob);
          if (strategy == DocumentRefStrategy.bookmarkWithPath) {
            // Desktop UX needs the path for "Show in Finder"; the bookmark
            // stays the source of truth for resolution. iOS keeps localPath
            // null because the picker path is sandbox-scoped.
            localPath = file.path;
          }
        case DocumentRefStrategy.persistableUri:
          // file_picker hands back two different things on Android:
          // `path`, a copy it made under `<cacheDir>/file_picker/`, and
          // `identifier`, the SAF content URI the user actually picked.
          // Only the URI can be persisted; handing the path to
          // takePersistableUriPermission throws PERMISSION_DENIED with a
          // blank URI in the message (issue #1002).
          bookmarkRef = await _takePersistableUri(file.identifier);
          if (bookmarkRef == null) {
            // No durable handle available (ACTION_GET_CONTENT pick, or a
            // provider that refuses persistable grants). Keep the cached
            // copy so the attachment works now; the media store upload
            // enqueued below is what makes it durable.
            localPath = file.path;
          }
        case DocumentRefStrategy.plainPath:
          localPath = file.path;
      }

      final now = DateTime.now();
      final item = MediaItem(
        // Empty id triggers UUID generation in MediaRepository.createMedia.
        id: '',
        diveId: diveId,
        siteId: siteId,
        mediaType: MediaType.document,
        sourceType: MediaSourceType.localFile,
        originalFilename: file.filename,
        localPath: localPath,
        bookmarkRef: bookmarkRef,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final saved = await mediaRepository.createMedia(item);
      onMediaCreated?.call(saved.id);
      created.add(saved);
    }
    return created;
  }

  /// Persists [identifier] as a SAF URI permission, or returns null when it
  /// is not a URI this device can persist.
  ///
  /// A refusal must not abort the import: the row is still worth creating
  /// against the picker's cached copy, which is what the media store
  /// upload reads. Before issue #1002 the whole attach threw instead.
  Future<String?> _takePersistableUri(String? identifier) async {
    if (!LocalMediaPlatform.isPersistableUri(identifier)) {
      _log.warning(
        'Document pick carried no SAF content URI; falling back to the '
        'picker path. The attachment is only durable if a media store is '
        'configured.',
      );
      return null;
    }
    try {
      return await platform.takePersistableUri(identifier!);
    } on PlatformException catch (e, st) {
      _log.warning(
        'takePersistableUri refused for $identifier; falling back to the '
        'picker path',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
