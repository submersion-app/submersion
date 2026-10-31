import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';

/// Media of a whole trip, read in one statement rather than one per dive
/// (issue #3832). Both reads cover the dives [TripRepository.getDiveIdsForTrip]
/// lists: the trip's and its side trips', limited to [diverId] when given.
class TripMediaRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(TripMediaRepository);

  /// Writes to the one table [getPreview] reads. Narrower than
  /// [MediaRepository.watchMediaChanges] on purpose: opening a photo backfills
  /// its enrichment, which no preview shows but which would recompose the
  /// whole trip story.
  Stream<void> watchPreviewChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.media))
      .debounce(MediaRepository.changeTickDebounce);

  /// The earliest [tripMediaPreviewLimit] items of each dive, with the counts
  /// of everything on it, so the row count is capped by the dives however
  /// many photos the trip holds.
  ///
  /// Only id and the ranking columns pass through the window functions; the
  /// full rows join back afterwards. A signature row stores its image inline,
  /// and SQLite's window sort would otherwise hold every one of them.
  Future<TripMediaPreview> getPreview(String tripId, {String? diverId}) async {
    try {
      final diverClause = diverId != null ? 'AND diver_id = ?' : '';
      final nonPhotoTypes = List.filled(
        kNonPhotoFileTypes.length,
        '?',
      ).join(', ');
      final rows = await _db
          .customSelect(
            '''
        -- stats-scope-exempt: previews the trip's displayed dive list, which
        -- shows excluded dives like the logbook does
        WITH trip_dives AS (
          SELECT id FROM dives
          WHERE ${tripDivesScopeSql('dives', '?1')}
          $diverClause
        ),
        ranked AS (
          SELECT m.id,
            ROW_NUMBER() OVER (
              PARTITION BY m.dive_id
              ORDER BY m.taken_at IS NULL, m.taken_at, m.id
            ) AS position,
            COUNT(*) OVER (PARTITION BY m.dive_id) AS media_count,
            SUM(m.file_type NOT IN ($nonPhotoTypes))
              OVER (PARTITION BY m.dive_id) AS photo_count
          FROM media m
          WHERE m.dive_id IN (SELECT id FROM trip_dives)
        )
        SELECT media.*, ranked.media_count, ranked.photo_count
        FROM ranked
        JOIN media ON media.id = ranked.id
        WHERE ranked.position <= ?
        ORDER BY media.dive_id, ranked.position
      ''',
            variables: [
              Variable.withString(tripId),
              if (diverId != null) Variable.withString(diverId),
              ...kNonPhotoFileTypes.map(Variable.withString),
              Variable.withInt(tripMediaPreviewLimit),
            ],
          )
          .get();

      final rowsByDive = <String, List<QueryRow>>{};
      for (final row in rows) {
        (rowsByDive[row.read<String>('dive_id')] ??= []).add(row);
      }
      return TripMediaPreview(
        byDiveId: {
          for (final MapEntry(key: diveId, value: diveRows)
              in rowsByDive.entries)
            diveId: DiveMediaPreview(
              items: [
                for (final row in diveRows)
                  mediaItemFromRow(_db.media.map(row.data)),
              ],
              mediaCount: diveRows.first.read<int>('media_count'),
              photoCount: diveRows.first.read<int>('photo_count'),
            ),
        },
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media preview for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Every media item of the trip with its enrichment, in chronological
  /// order, for the gallery, the viewer and the scan's linked-asset check.
  Future<List<MediaItem>> getMediaForTrip(
    String tripId, {
    String? diverId,
  }) async {
    try {
      final diverClause = diverId != null ? 'AND diver_id = ?' : '';
      // Aliased so the enrichment columns survive next to media's own, in the
      // form drift's tablePrefix reads them back.
      final enrichmentColumns = _db.mediaEnrichment.$columns
          .map((c) => 'e.${c.$name} AS "e.${c.$name}"')
          .join(', ');
      final rows = await _db
          .customSelect(
            '''
        -- stats-scope-exempt: the trip's displayed dive list, which shows
        -- excluded dives like the logbook does
        SELECT m.*, $enrichmentColumns
        FROM media m
        LEFT JOIN media_enrichment e ON e.media_id = m.id
        WHERE m.dive_id IN (
          SELECT id FROM dives
          WHERE ${tripDivesScopeSql('dives', '?1')}
          $diverClause
        )
        ORDER BY m.taken_at IS NULL, m.taken_at, m.id
      ''',
            variables: [
              Variable.withString(tripId),
              if (diverId != null) Variable.withString(diverId),
            ],
          )
          .get();

      return [
        for (final row in rows)
          mediaItemFromRow(
            _db.media.map(row.data),
            row.data['e.id'] == null
                ? null
                : _db.mediaEnrichment.map(row.data, tablePrefix: 'e'),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
