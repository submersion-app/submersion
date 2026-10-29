import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// Rewrites every saved smart album whose filter names one of [fromTagIds]
/// to name [toTagId] instead (issue #1970), for a tag merge that is about to
/// delete [fromTagIds]. Without it an album filtered by a merged tag would
/// match nothing from then on.
///
/// Keys this build does not know are kept, so an album saved by a newer
/// build loses nothing. Each rewritten album is stamped and marked pending.
/// Runs inside the caller's transaction and does not notify.
Future<void> repointSmartAlbumTags(
  AppDatabase db,
  SyncRepository syncRepository, {
  required List<String> fromTagIds,
  required String toTagId,
  required int now,
}) async {
  final from = fromTagIds.toSet();
  await repointSmartAlbums(
    db,
    syncRepository,
    names: (filter) => filter.tagIds.any(from.contains),
    repoint: (filter) => filter.copyWith(
      tagIds: {
        for (final id in filter.tagIds) from.contains(id) ? toTagId : id,
      },
    ),
    now: now,
  );
}

/// Rewrites every saved smart album whose filter [names] something being
/// merged away, using [repoint], the loop the tag and buddy merges share.
///
/// Keys this build does not know are kept, so an album saved by a newer
/// build loses nothing. Each rewritten album is stamped and marked pending.
/// Returns each rewritten album's previous filter JSON, for an undo. Runs
/// inside the caller's transaction and does not notify.
Future<Map<String, String>> repointSmartAlbums(
  AppDatabase db,
  SyncRepository syncRepository, {
  required bool Function(MediaLibraryFilter filter) names,
  required MediaLibraryFilter Function(MediaLibraryFilter filter) repoint,
  required int now,
}) async {
  final previous = <String, String>{};
  for (final row in await db.select(db.mediaSmartAlbums).get()) {
    final Object? decoded;
    try {
      decoded = jsonDecode(row.filterJson);
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, dynamic>) continue;
    final filter = MediaLibraryFilter.fromJson(decoded);
    if (!names(filter)) continue;
    previous[row.id] = row.filterJson;
    await (db.update(
      db.mediaSmartAlbums,
    )..where((t) => t.id.equals(row.id))).write(
      MediaSmartAlbumsCompanion(
        filterJson: Value(
          jsonEncode({...decoded, ...repoint(filter).toJson()}),
        ),
        updatedAt: Value(now),
      ),
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaSmartAlbums',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
  return previous;
}
