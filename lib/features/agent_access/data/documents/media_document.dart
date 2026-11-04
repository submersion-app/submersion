import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The agent-facing view of a media item, without its bytes, its URL or
/// its file paths.
///
/// A whitelist, because a signature row carries its image bytes in
/// [MediaItem.imageData], a private feed's item URL can carry an access
/// token, and a path names the diver's own disk layout. Nothing an agent
/// does needs any of them.
Map<String, Object?> mediaDocument(MediaItem m) {
  return {
    'id': m.id,
    'dive_id': m.diveId,
    'site_id': m.siteId,
    'equipment_id': m.equipmentId,
    'source_type': m.sourceType.name,
    'media_type': m.mediaType.name,
    'original_filename': m.originalFilename,
    // Already a wall clock; toUtc only matters to a row with no taken_at, which
    // the mapper fills from a local now.
    'captured_time': wallClock(m.takenAt.toUtc()),
    'latitude': m.latitude,
    'longitude': m.longitude,
    'width_px': m.width,
    'height_px': m.height,
    'duration_s': m.durationSeconds,
    'caption': m.caption,
    'is_favorite': m.isFavorite,
    'is_orphaned': m.isOrphaned,
    'signer_id': m.signerId,
    'signer_name': m.signerName,
  };
}
