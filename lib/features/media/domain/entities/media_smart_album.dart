import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// A named saved library filter (Media section Phase 5).
///
/// The album IS its filter: nothing is materialized, so an album stays
/// current as media arrives and changes.
class MediaSmartAlbum {
  const MediaSmartAlbum({
    required this.id,
    required this.name,
    required this.filter,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final MediaLibraryFilter filter;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}
