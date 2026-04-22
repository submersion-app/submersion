import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/universal_import/data/services/imported_photo_storage.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';

/// Outcome of [ImportedPhotoLinkService.linkAll]. Intended for logging +
/// user-facing warning display; no error is raised when photos fail to land
/// because dives are already safely imported by the time this runs.
class ImportedPhotoLinkResult {
  /// Number of photos successfully written to disk and linked via
  /// [MediaRepository].
  final int written;

  /// Number of resolved photos with null bytes (resolver misses that the
  /// user chose not to re-resolve). Counted but not fatal.
  final int missingBytes;

  /// Number of resolved photos whose [ResolvedPhoto.ref.diveSourceUuid]
  /// did not match any newly-created dive (for example because the user
  /// deselected the dive as a duplicate). Silently dropped — MediaItem is
  /// skipped for these.
  final int orphanDive;

  /// Number of photos whose file write or MediaRepository insert raised.
  /// Logged, counted, and otherwise swallowed so one bad photo cannot
  /// fail the entire post-import pipeline.
  final int failures;

  const ImportedPhotoLinkResult({
    this.written = 0,
    this.missingBytes = 0,
    this.orphanDive = 0,
    this.failures = 0,
  });

  bool get isAllWritten =>
      missingBytes == 0 && orphanDive == 0 && failures == 0;
}

/// Writes resolved photos to disk and registers them as [MediaItem] rows
/// linked to the newly-created dives.
///
/// Invoked by the import wizard after [UddfEntityImporter.import] finishes —
/// dives already exist in the DB by then, along with their `source_uuid`
/// mappings. This service bridges the wizard's `ResolvedPhoto` list to
/// [ImportedPhotoStorage] + [MediaRepository].
///
/// Robustness guarantees (in priority order):
///   1. A null-bytes photo (resolver miss the user accepted) is a no-op.
///   2. An unknown source UUID (the dive was skipped via duplicate action) is
///      a no-op — no orphan files written, no orphan MediaItem rows.
///   3. A write or DB failure on one photo does NOT abort the loop; it is
///      logged and the remaining photos are processed.
///
/// Returns counts for telemetry / summary display; does not throw.
class ImportedPhotoLinkService {
  final ImportedPhotoStorage _storage;
  final MediaRepository _mediaRepository;
  final _log = LoggerService.forClass(ImportedPhotoLinkService);

  ImportedPhotoLinkService({
    required ImportedPhotoStorage storage,
    required MediaRepository mediaRepository,
  }) : _storage = storage,
       _mediaRepository = mediaRepository;

  /// Process every [resolved] photo against [sourceUuidToDiveId].
  ///
  /// For each photo: if bytes are present AND sourceUuid resolves to a dive,
  /// write the file to the per-dive media folder and insert a MediaItem row
  /// carrying `filePath`, `originalFilename`, and `caption`. Missing bytes
  /// and unknown UUIDs are counted but not errors.
  Future<ImportedPhotoLinkResult> linkAll({
    required List<ResolvedPhoto> resolved,
    required Map<String, String> sourceUuidToDiveId,
  }) async {
    var written = 0;
    var missingBytes = 0;
    var orphanDive = 0;
    var failures = 0;

    for (final photo in resolved) {
      final bytes = photo.bytes;
      if (bytes == null) {
        missingBytes++;
        continue;
      }

      final diveId = sourceUuidToDiveId[photo.ref.diveSourceUuid];
      if (diveId == null) {
        _log.info(
          'Skipping photo for dive sourceUuid=${photo.ref.diveSourceUuid}: '
          'no matching imported dive (likely deselected as duplicate)',
        );
        orphanDive++;
        continue;
      }

      try {
        final file = await _storage.store(
          diveId: diveId,
          ref: photo.ref,
          bytes: bytes,
        );

        final now = DateTime.now();
        await _mediaRepository.createMedia(
          MediaItem(
            id: '',
            diveId: diveId,
            filePath: file.path,
            originalFilename: photo.ref.filename,
            caption: photo.ref.caption,
            mediaType: MediaType.photo,
            takenAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
        written++;
      } catch (e, stackTrace) {
        _log.error(
          'Failed to store imported photo for dive $diveId '
          '(original: ${photo.ref.originalPath})',
          error: e,
          stackTrace: stackTrace,
        );
        failures++;
      }
    }

    return ImportedPhotoLinkResult(
      written: written,
      missingBytes: missingBytes,
      orphanDive: orphanDive,
      failures: failures,
    );
  }
}
