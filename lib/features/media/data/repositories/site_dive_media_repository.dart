import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Media linked to the dives logged at a site, read in one statement rather
/// than by hydrating every dive and querying each one (issue #4252).
///
/// Both reads cover every dive whose `site_id` is the site, whichever diver
/// logged it, the same set [DiveRepository.getDivesForSite] returns. Media
/// attached to the site directly is the attachments group's, and appears
/// here only when it is also linked to one of those dives.
class SiteDiveMediaRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(SiteDiveMediaRepository);

  /// Writes to the one table [countMediaFromDivesAtSite] reads. Narrower
  /// than [MediaRepository.watchMediaChanges] on purpose: opening a photo
  /// backfills its enrichment, which changes no count.
  Stream<void> watchCountChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.media))
      .debounce(MediaRepository.changeTickDebounce);

  /// How many media items the dives at [siteId] hold. What the collapsed
  /// group needs to decide whether to show and what to put in its title,
  /// answered from `idx_dives_site_id` and `idx_media_dive_taken` alone.
  // stats-scope-exempt: counts a displayed gallery, which shows the media of
  // excluded dives like the logbook shows the dives themselves.
  Future<int> countMediaFromDivesAtSite(String siteId) async {
    try {
      final row = await _db
          .customSelect(
            '''
        SELECT COUNT(*) AS media_count
        FROM media
        WHERE dive_id IN (SELECT id FROM dives WHERE site_id = ?)
      ''',
            variables: [Variable.withString(siteId)],
          )
          .getSingle();
      return row.read<int>('media_count');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to count media from dives at site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Every media item on the dives at [siteId] with its enrichment, in
  /// chronological order, for the expanded group and the site viewer.
  // stats-scope-exempt: a displayed gallery, which shows the media of
  // excluded dives like the logbook shows the dives themselves.
  Future<List<MediaItem>> getMediaFromDivesAtSite(String siteId) async {
    try {
      final rows = await _db
          .customSelect(
            '''
        SELECT m.*, ${enrichmentSelectColumns(_db)}
        FROM media m
        LEFT JOIN media_enrichment e ON e.media_id = m.id
        WHERE m.dive_id IN (SELECT id FROM dives WHERE site_id = ?)
        ORDER BY m.taken_at IS NULL, m.taken_at, m.id
      ''',
            variables: [Variable.withString(siteId)],
          )
          .get();

      return [for (final row in rows) mediaItemFromJoinedRow(_db, row)];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media from dives at site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
