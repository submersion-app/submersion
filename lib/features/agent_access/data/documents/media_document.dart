import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The agent-facing view of a media item: links only, never bytes.
///
/// A whitelist, because a signature row carries its image bytes in
/// [MediaItem.imageData] and nothing an agent does needs them.
Map<String, Object?> mediaDocument(MediaItem m) {
  return {
    'id': m.id,
    'source_type': m.sourceType.name,
    'file_path': m.filePath,
    'local_path': m.localPath,
    'url': m.url,
    'thumbnail_path': m.thumbnailPath,
    'captured_at': m.takenAt.toIso8601String(),
  };
}
