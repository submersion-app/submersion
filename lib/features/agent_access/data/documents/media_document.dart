import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The agent-facing view of a media item: links only, never bytes.
///
/// A whitelist, because a signature row carries its image bytes in
/// [MediaItem.imageData] and nothing an agent does needs them.
Map<String, Object?> mediaDocument(MediaItem m) {
  return {
    'id': m.id,
    'dive_id': m.diveId,
    'site_id': m.siteId,
    'equipment_id': m.equipmentId,
    'source_type': m.sourceType.name,
    'media_type': m.mediaType.name,
    'file_path': m.filePath,
    'local_path': m.localPath,
    'url': m.url,
    'thumbnail_path': m.thumbnailPath,
    'original_filename': m.originalFilename,
    'captured_at': instant(m.takenAt),
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
