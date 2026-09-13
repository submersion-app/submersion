import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Maps a `tags` row to its domain entity. Shared by every reader, so a new
/// column (like the v214 scope flags) is mapped in exactly one place.
domain.Tag mapTagRow(Tag row) {
  return domain.Tag(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    colorHex: row.color,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    appliesToDives: row.appliesToDives,
    appliesToSites: row.appliesToSites,
  );
}
