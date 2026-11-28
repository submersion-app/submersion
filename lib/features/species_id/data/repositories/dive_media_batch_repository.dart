import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The media of many dives at once, for counting and running Find species
/// over a selection, a trip or the whole logbook (issue #5127).
class DiveMediaBatchRepository {
  DiveMediaBatchRepository({AppDatabase? database}) : _database = database;

  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Every dive's media, oldest first, as `getMediaForDive` reads one
  /// dive's. Every id is in the map, a dive with none mapping to an empty
  /// list.
  Future<Map<String, List<MediaItem>>> mediaForDives(
    List<String> diveIds,
  ) async {
    final byDive = <String, List<MediaItem>>{
      for (final id in diveIds) id: <MediaItem>[],
    };
    if (diveIds.isEmpty) return byDive;
    final db = _db;
    for (final chunk in seriesIdChunks(diveIds)) {
      final query =
          db.select(db.media).join([
              leftOuterJoin(
                db.mediaEnrichment,
                db.mediaEnrichment.mediaId.equalsExp(db.media.id),
              ),
            ])
            ..where(db.media.diveId.isIn(chunk))
            ..orderBy([OrderingTerm.asc(db.media.takenAt)]);
      for (final row in await query.get()) {
        final item = mediaItemFromRow(
          row.readTable(db.media),
          row.readTableOrNull(db.mediaEnrichment),
        );
        final diveId = item.diveId;
        if (diveId != null) byDive[diveId]?.add(item);
      }
    }
    return byDive;
  }

  /// The dives with a photo or video, newest first, so a run over the whole
  /// logbook starts with the dives the diver remembers best. [diverId]
  /// keeps it to that diver's dives.
  Future<List<String>> diveIdsWithMedia({String? diverId}) async {
    final db = _db;
    // Not a list of photo spellings: every legacy one reads as a photo.
    final notBrowsed = List.filled(
      kNonBrowsableFileTypes.length,
      '?',
    ).join(', ');
    final rows = await db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'WHERE EXISTS (SELECT 1 FROM media m WHERE m.dive_id = d.id '
          'AND m.file_type NOT IN ($notBrowsed)) '
          '${diverId == null ? '' : 'AND d.diver_id = ? '}'
          'ORDER BY d.dive_date_time DESC, d.id',
          variables: [
            for (final t in kNonBrowsableFileTypes) Variable.withString(t),
            if (diverId != null) Variable.withString(diverId),
          ],
          readsFrom: {db.dives, db.media},
        )
        .get();
    return [for (final row in rows) row.read<String>('id')];
  }
}
