import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dashboard/domain/home_outings.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// The reads behind the covers of Home's Recent outings postcards
/// (issue #4898): which photos and videos on a set of dives could be a
/// cover, and the chosen items themselves.
class OutingCoverRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(OutingCoverRepository);

  /// The photos and videos linked to [diveIds], leaving out orphaned rows,
  /// signatures, documents and media attached only to a site. A species tag
  /// counts only once the diver owns it: an app-applied tag still awaiting
  /// confirmation (`unconfirmed = 1`) does not.
  Future<List<CoverCandidate>> getCoverCandidates(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    try {
      final placeholders = List.filled(diveIds.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            '''
        SELECT
          m.id AS id,
          m.dive_id AS dive_id,
          m.file_type AS file_type,
          m.is_favorite AS is_favorite,
          m.taken_at AS taken_at,
          EXISTS (
            SELECT 1 FROM media_species ms
            WHERE ms.media_id = m.id AND COALESCE(ms.unconfirmed, 0) = 0
          ) AS tagged
        FROM media m
        WHERE m.dive_id IN ($placeholders)
          AND m.file_type IN ('photo', 'video')
          AND m.is_orphaned = 0
        ''',
            variables: [for (final id in diveIds) Variable<String>(id)],
          )
          .get();
      return [
        for (final row in rows)
          CoverCandidate(
            mediaId: row.read<String>('id'),
            diveId: row.read<String>('dive_id'),
            isVideo: row.read<String>('file_type') == 'video',
            isFavorite: row.read<bool>('is_favorite'),
            hasSpeciesTag: row.read<bool>('tagged'),
            takenAt: switch (row.readNullable<int>('taken_at')) {
              final int ms => DateTime.fromMillisecondsSinceEpoch(
                ms,
                isUtc: true,
              ),
              null => null,
            },
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get outing cover candidates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The media items [ids] names, in no particular order.
  Future<List<MediaItem>> getMediaByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final placeholders = List.filled(ids.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            '''
        SELECT m.*, ${enrichmentSelectColumns(_db)}
        FROM media m
        LEFT JOIN media_enrichment e ON e.media_id = m.id
        WHERE m.id IN ($placeholders)
        ''',
            variables: [for (final id in ids) Variable<String>(id)],
          )
          .get();
      return [for (final row in rows) mediaItemFromJoinedRow(_db, row)];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get outing covers',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
