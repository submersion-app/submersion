import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_file_handle_factory.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// Reads capture metadata for a file about to be linked. Null when the file
/// cannot be read; the link still happens, with the caller's fallbacks.
typedef LocalFileMetadataReader =
    Future<MediaSourceMetadata?> Function(File file);

/// Links a file on this device to a dive as a `localFile` media row that
/// references the file in place.
///
/// Nothing is copied: the row stores the [LocalFileHandle] the factory
/// mints, so the photo lives wherever the user keeps it and Submersion
/// never touches the original. This is the import wizard's counterpart to
/// the Files tab's persistence, built on the same handle factory so the
/// two cannot drift.
class LocalFileLinkService {
  LocalFileLinkService({
    required MediaRepository mediaRepository,
    required LocalFileHandleFactory handles,
    required LocalFileMetadataReader readMetadata,
    this.onMediaCreated,
  }) : _mediaRepository = mediaRepository,
       _handles = handles,
       _readMetadata = readMetadata;

  final MediaRepository _mediaRepository;
  final LocalFileHandleFactory _handles;
  final LocalFileMetadataReader _readMetadata;
  final _log = LoggerService.forClass(LocalFileLinkService);

  /// Invoked after every successful createMedia so the media store can
  /// enqueue an upload. Null when no store is configured.
  final void Function(String mediaId)? onMediaCreated;

  /// The local paths already linked to [diveId], the dedupe key for
  /// [linkFileForDive]. Fetch once per dive and pass the same set to every
  /// link for that dive; the service adds each new path to it.
  ///
  /// iOS rows carry only a bookmark, no path, so they are invisible here.
  /// That is fine while the wizard's Photos step is desktop-only; a mobile
  /// Photos step would need a bookmark-aware dedupe before shipping.
  Future<Set<String>> linkedPathsForDive(String diveId) =>
      _mediaRepository.getLinkedLocalPathsForDive(diveId);

  /// Video extensions the app can hold. Only consulted when the metadata
  /// read gave us no mime type to go on.
  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.avi',
    '.mkv',
    '.webm',
  };

  /// Photo or video, from the mime type when there is one and from the
  /// extension when there is not.
  ///
  /// Metadata extraction is what supplies the mime type, so an unreadable
  /// file leaves none. Defaulting that to a photo would give a video a row
  /// that never plays and never gets a thumbnail.
  static MediaType _mediaTypeFor(String path, MediaSourceMetadata? metadata) {
    final mimeType = metadata?.mimeType ?? '';
    if (mimeType.startsWith('video/')) return MediaType.video;
    if (mimeType.startsWith('image/')) return MediaType.photo;
    return _videoExtensions.contains(p.extension(path).toLowerCase())
        ? MediaType.video
        : MediaType.photo;
  }

  /// The metadata time, but only when it came from the file's own capture
  /// record.
  ///
  /// The extractor's cascade never yields null for a readable file: with
  /// no capture record it returns the file's modification time. For a
  /// photo just written out of an archive that is the moment of the copy,
  /// so taking it blindly would stamp today's date on a photo whose dive
  /// start is known and correct.
  static DateTime? _capturedAt(MediaSourceMetadata? metadata) {
    if (metadata == null) return null;
    return switch (metadata.takenAtSource) {
      TakenAtSource.nativeExif ||
      TakenAtSource.containerMetadata => metadata.takenAt,
      _ => null,
    };
  }

  /// Links [path] to [diveId], or returns null when [linkedPaths] already
  /// holds the path so a re-run of the same import never double-links.
  /// Throws a [FileSystemException] when nothing exists at [path].
  ///
  /// [takenAt] is a capture time the source asserted (a logbook's own
  /// offset from dive start); it wins over the file's own capture record,
  /// which wins over [fallbackTakenAt] (typically the dive start), which
  /// wins over a filesystem timestamp, which wins over now. [latitude] and
  /// [longitude] follow the same rule against EXIF.
  Future<MediaItem?> linkFileForDive({
    required String path,
    required String diveId,
    required Set<String> linkedPaths,
    DateTime? takenAt,
    DateTime? fallbackTakenAt,
    double? latitude,
    double? longitude,
    String? caption,
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.mediaImport);
    if (linkedPaths.contains(path)) {
      _log.info('Skipping already-linked $path for dive $diveId');
      return null;
    }
    // Fail fast rather than write a row that is broken from birth: a file
    // can vanish between the wizard resolving it and the import committing,
    // and the attach loop counts a thrown link as a failure it can report.
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Photo not found', path);
    }

    MediaSourceMetadata? metadata;
    try {
      metadata = await _readMetadata(file);
    } catch (e) {
      // Metadata is a nicety; the link itself must not depend on a
      // readable EXIF block.
      _log.warning('Could not read metadata for $path: $e');
    }

    final handle = await _handles.create(path);
    final now = DateTime.now();
    final item = MediaItem(
      // Empty id triggers UUID generation in MediaRepository.createMedia.
      id: '',
      diveId: diveId,
      mediaType: _mediaTypeFor(path, metadata),
      sourceType: MediaSourceType.localFile,
      originalFilename: p.basename(path),
      localPath: handle.localPath,
      bookmarkRef: handle.bookmarkRef,
      caption: caption,
      takenAt:
          takenAt ??
          _capturedAt(metadata) ??
          fallbackTakenAt ??
          metadata?.takenAt ??
          now,
      latitude: latitude ?? metadata?.latitude,
      longitude: longitude ?? metadata?.longitude,
      width: metadata?.width,
      height: metadata?.height,
      durationSeconds: metadata?.durationSeconds,
      createdAt: now,
      updatedAt: now,
    );

    final saved = await _mediaRepository.createMedia(item);
    linkedPaths.add(path);
    onMediaCreated?.call(saved.id);
    return saved;
  }
}
