import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

const _log = LoggerService('MediaRowMapper');

/// Maps a Drift media row (plus optional enrichment row) to the domain
/// MediaItem. Shared by MediaRepository and MediaLibraryRepository so the
/// two can never drift apart on hydration rules (takenAt is UTC, source
/// type parsing, enrichment merge).
domain.MediaItem mediaItemFromRow(
  MediaData row, [
  MediaEnrichmentData? enrichmentRow,
]) {
  return domain.MediaItem(
    id: row.id,
    diveId: row.diveId,
    siteId: row.siteId,
    platformAssetId: row.platformAssetId,
    filePath: row.filePath,
    originalFilename: row.originalFilename,
    mediaType: parseMediaType(row.fileType),
    latitude: row.latitude,
    longitude: row.longitude,
    // taken_at is stored as wall-clock-UTC millis (see the write path and the
    // dive side, which reads entry_time with isUtc: true). Hydrate it as UTC
    // so downstream normalisation (TripMediaScanner.toWallClockUtc, invoked by
    // EnrichmentService.calculateEnrichment) is a no-op instead of shifting the
    // photo time by the host's UTC offset.
    takenAt: row.takenAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.takenAt!, isUtc: true)
        : _defaultTakenAt(row.id),
    width: row.width,
    height: row.height,
    durationSeconds: row.durationSeconds,
    caption: row.caption,
    isFavorite: row.isFavorite,
    thumbnailPath: null, // Not stored in database
    thumbnailGeneratedAt: row.thumbnailGeneratedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.thumbnailGeneratedAt!)
        : null,
    lastVerifiedAt: row.lastVerifiedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.lastVerifiedAt!)
        : null,
    isOrphaned: row.isOrphaned,
    signerId: row.signerId,
    signerName: row.signerName,
    imageData: row.imageData,
    sourceType:
        MediaSourceType.fromString(row.sourceType) ??
        MediaSourceType.platformGallery,
    localPath: row.localPath,
    bookmarkRef: row.bookmarkRef,
    url: row.url,
    subscriptionId: row.subscriptionId,
    entryKey: row.entryKey,
    connectorAccountId: row.connectorAccountId,
    remoteAssetId: row.remoteAssetId,
    originDeviceId: row.originDeviceId,
    contentHash: row.contentHash,
    contentSizeBytes: row.contentSizeBytes,
    remoteUploadedAt: row.remoteUploadedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.remoteUploadedAt!)
        : null,
    remoteThumbUploadedAt: row.remoteThumbUploadedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.remoteThumbUploadedAt!)
        : null,
    compressedLevel: row.compressedLevel,
    compressedSizeBytes: row.compressedSizeBytes,
    remoteCompressedUploadedAt: row.remoteCompressedUploadedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.remoteCompressedUploadedAt!)
        : null,
    retainInLibrary: row.retainInLibrary,
    manualElapsedSeconds: row.manualElapsedSeconds,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    enrichment: enrichmentRow != null
        ? mediaEnrichmentFromRow(enrichmentRow)
        : null,
  );
}

domain.MediaEnrichment mediaEnrichmentFromRow(MediaEnrichmentData row) {
  return domain.MediaEnrichment(
    id: row.id,
    mediaId: row.mediaId,
    diveId: row.diveId,
    depthMeters: row.depthMeters,
    temperatureCelsius: row.temperatureCelsius,
    elapsedSeconds: row.elapsedSeconds,
    matchConfidence:
        domain.MatchConfidence.fromString(row.matchConfidence) ??
        domain.MatchConfidence.noProfile,
    timestampOffsetSeconds: row.timestampOffsetSeconds,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  );
}

/// Every file_type spelling that means "instructor signature".
///
/// Signatures are excluded from every library surface, so the exclusion has
/// to know about the legacy camelCase spelling [parseMediaType] still
/// accepts -- filtering on the snake_case value alone lets old rows through.
const List<String> kSignatureFileTypes = [
  'instructor_signature',
  'instructorSignature',
];

/// Parses database file_type string to MediaType enum.
/// Handles both snake_case (database format) and camelCase (legacy) for
/// compatibility.
domain.MediaType parseMediaType(String value) {
  switch (value) {
    case 'video':
      return domain.MediaType.video;
    case 'instructor_signature':
    case 'instructorSignature':
      return domain.MediaType.instructorSignature;
    case 'document':
      return domain.MediaType.document;
    default:
      return domain.MediaType.photo;
  }
}

String mediaTypeToDbString(domain.MediaType type) {
  switch (type) {
    case domain.MediaType.video:
      return 'video';
    case domain.MediaType.instructorSignature:
      return 'instructor_signature';
    case domain.MediaType.photo:
      return 'photo';
    case domain.MediaType.document:
      return 'document';
  }
}

/// Returns a default DateTime when takenAt is null in database.
/// Logs a warning since this indicates data integrity issues.
DateTime _defaultTakenAt(String mediaId) {
  _log.warning('Media $mediaId has null takenAt, defaulting to now');
  return DateTime.now();
}
