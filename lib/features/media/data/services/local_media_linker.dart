import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// Turns a (diveId, [MediaHandle], [MediaSourceMetadata]) into a persisted
/// `localFile` [MediaItem]. Extracted from `FilesTabNotifier._persistOne`
/// so imported photos and Files-tab photos share one persistence path and
/// cannot drift.
///
/// Handle handling (independent, so macOS can carry blob + path together):
/// - [MediaHandle.bookmarkBlob] -> written to the keychain under a fresh
///   UUID; that UUID becomes `bookmarkRef` (iOS / macOS).
/// - [MediaHandle.contentUri] -> stored as `bookmarkRef` (Android).
/// - [MediaHandle.localPath] -> stored as `localPath` (desktop, and macOS
///   alongside the bookmark for "Show in Finder").
class LocalMediaLinker {
  LocalMediaLinker({
    required this.mediaRepository,
    required this.bookmarkStorage,
  });

  final MediaRepository mediaRepository;
  final LocalBookmarkStorage bookmarkStorage;

  static const _uuid = Uuid();
  final _log = LoggerService.forClass(LocalMediaLinker);

  /// Persists one file as a `localFile` [MediaItem] linked to [diveId] and
  /// returns the created item.
  Future<MediaItem> link({
    required String diveId,
    required MediaHandle handle,
    required String basename,
    required MediaSourceMetadata metadata,
    required DateTime fallbackTakenAt,
    String? caption,
  }) async {
    try {
      String? localPath;
      String? bookmarkRef;

      if (handle.bookmarkBlob != null) {
        bookmarkRef = _uuid.v4();
        await bookmarkStorage.write(bookmarkRef, handle.bookmarkBlob!);
      }
      if (handle.contentUri != null) {
        bookmarkRef = handle.contentUri;
      }
      if (handle.localPath != null) {
        localPath = handle.localPath;
      }

      final isVideo = metadata.mimeType.startsWith('video/');
      final now = DateTime.now();
      final item = MediaItem(
        // Empty id triggers UUID generation in MediaRepository.createMedia.
        id: '',
        diveId: diveId,
        mediaType: isVideo ? MediaType.video : MediaType.photo,
        sourceType: MediaSourceType.localFile,
        localPath: localPath,
        bookmarkRef: bookmarkRef,
        filePath: localPath,
        originalFilename: basename,
        caption: caption,
        takenAt: metadata.takenAt ?? fallbackTakenAt,
        latitude: metadata.latitude,
        longitude: metadata.longitude,
        width: metadata.width,
        height: metadata.height,
        durationSeconds: metadata.durationSeconds,
        createdAt: now,
        updatedAt: now,
      );

      return await mediaRepository.createMedia(item);
    } catch (e, st) {
      _log.error(
        'Failed to link local media for dive: $diveId',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
