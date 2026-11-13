import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';

const _log = LoggerService('MediaRowMapper');

/// The `media_enrichment` columns for a raw select that LEFT JOINs it as `e`
/// next to `media.*`. Each is aliased `"e.<name>"` so it survives beside
/// media's own columns of the same name, in the form drift's tablePrefix
/// reads back. Pair with [mediaItemFromJoinedRow].
String enrichmentSelectColumns(AppDatabase db) => db.mediaEnrichment.$columns
    .map((c) => 'e.${c.$name} AS "e.${c.$name}"')
    .join(', ');

/// Maps a raw row holding `media.*` and [enrichmentSelectColumns]; the
/// enrichment is null when the LEFT JOIN found none.
domain.MediaItem mediaItemFromJoinedRow(AppDatabase db, QueryRow row) =>
    mediaItemFromRow(
      db.media.map(row.data),
      row.data['e.id'] == null
          ? null
          : db.mediaEnrichment.map(row.data, tablePrefix: 'e'),
    );

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
    equipmentId: row.equipmentId,
    observationId: row.observationId,
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
        : _defaultTakenAt(row.id, row.createdAt),
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
    cloudAssetId: row.cloudAssetId,
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
    remoteStoreId: row.remoteStoreId,
    retainInLibrary: row.retainInLibrary,
    manualElapsedSeconds: row.manualElapsedSeconds,
    siteCategory: SiteAttachmentCategory.fromStorageKey(row.siteCategory),
    displaySizeOverride: AttachmentDisplaySize.fromStorageKey(row.displaySize),
    colorAdjustment: ColorAdjustment.fromJsonString(row.colorAdjustment),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    enrichment: enrichmentRow != null
        ? mediaEnrichmentFromRow(enrichmentRow)
        : null,
  );
}

/// The columns [galleryLinkFromRow] reads.
List<Expression<Object>> galleryLinkColumns($MediaTable m) => [
  m.id,
  m.diveId,
  m.siteId,
  m.platformAssetId,
  m.originalFilename,
  m.fileType,
  m.takenAt,
  m.width,
  m.height,
  m.createdAt,
  m.updatedAt,
];

/// A media row reduced to what gallery matching reads: identity, capture
/// time, size and filename, hydrated by the same rules as
/// [mediaItemFromRow]. Every other field keeps its default. The point is
/// what is NOT read: `image_data` holds whole signature images and gallery
/// dedupe runs before every import and picker open.
domain.MediaItem galleryLinkFromRow(TypedResult row, $MediaTable m) {
  final id = row.read(m.id)!;
  final takenAt = row.read(m.takenAt);
  return domain.MediaItem(
    id: id,
    diveId: row.read(m.diveId),
    siteId: row.read(m.siteId),
    platformAssetId: row.read(m.platformAssetId),
    originalFilename: row.read(m.originalFilename),
    mediaType: parseMediaType(row.read(m.fileType)!),
    takenAt: takenAt != null
        ? DateTime.fromMillisecondsSinceEpoch(takenAt, isUtc: true)
        : _defaultTakenAt(id, row.read(m.createdAt)!),
    width: row.read(m.width),
    height: row.read(m.height),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.read(m.createdAt)!),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read(m.updatedAt)!),
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

/// Every file_type spelling that means "this row is a signature".
///
/// Signatures are excluded from every library surface, so the exclusion has
/// to know about the legacy camelCase spelling [parseMediaType] still
/// accepts -- filtering on the snake_case value alone lets old rows through.
///
/// 'buddy_signature' is here because buddy signatures are signatures too.
/// It was absent while `SignatureStorageService.saveBuddySignature` could
/// never actually write a row (issue #1358), which hid the gap: with the
/// insert fixed, a buddy signature that is not listed here parses as
/// `MediaType.photo` and shows up as a dive photo.
const List<String> kSignatureFileTypes = [
  'instructor_signature',
  'instructorSignature',
  'buddy_signature',
];

/// Every file_type spelling that is neither a photo nor a video: the rows a
/// diver does not browse as media (documents, signatures). For SQL that has
/// to leave them out without hydrating rows; excluding them keeps every
/// legacy photo spelling [parseMediaType] accepts, which `IN ('photo', ...)`
/// would miss.
const List<String> kNonBrowsableFileTypes = [
  'document',
  ...kSignatureFileTypes,
];

/// Every file_type spelling that is not a photo, for SQL that has to count
/// photos without hydrating rows. [parseMediaType] reads anything else as a
/// photo, so filtering on 'photo' alone would miss rows it accepts.
const List<String> kNonPhotoFileTypes = ['video', ...kNonBrowsableFileTypes];

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

/// The capture time of a row whose taken_at is NULL: its created_at, read
/// the way taken_at is (wall-clock-as-UTC). Logs a warning since this
/// indicates data integrity issues.
///
/// The library's date key is COALESCE(taken_at, created_at), so this is the
/// time the row sorts by, and the Timeline groups it under that same day
/// (issue #4268). Defaulting to now filed every such row under today, apart
/// from the rows it was paged with.
DateTime _defaultTakenAt(String mediaId, int createdAtMillis) {
  _log.warning('Media $mediaId has null takenAt, defaulting to createdAt');
  return DateTime.fromMillisecondsSinceEpoch(createdAtMillis, isUtc: true);
}
