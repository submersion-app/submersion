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

  /// Every read here leaves out documents and signatures attached to a dive:
  /// they are not photos a diver browses (PR #4505 review), and the count,
  /// the strip and the viewer's list must agree on what they hold.
  static final String _nonBrowsablePlaceholders = List.filled(
    kNonBrowsableFileTypes.length,
    '?',
  ).join(', ');
  static final List<Variable<String>> _nonBrowsableVariables = [
    for (final type in kNonBrowsableFileTypes) Variable.withString(type),
  ];

  /// Writes to the one table [countMediaFromDivesAtSite] reads. Narrower
  /// than [MediaRepository.watchMediaChanges] on purpose: opening a photo
  /// backfills its enrichment, which changes no count.
  Stream<void> watchCountChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.media))
      .debounce(MediaRepository.changeTickDebounce);

  /// How many media items the dives at [siteId] hold. What Site Details
  /// needs to decide whether to show the dive photos card and how to title it,
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
          AND file_type NOT IN ($_nonBrowsablePlaceholders)
      ''',
            variables: [Variable.withString(siteId), ..._nonBrowsableVariables],
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
  /// chronological order, for the dive photos card's Show all grid and the
  /// site viewer.
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
          AND m.file_type NOT IN ($_nonBrowsablePlaceholders)
        ORDER BY m.taken_at IS NULL, m.taken_at, m.id
      ''',
            variables: [Variable.withString(siteId), ..._nonBrowsableVariables],
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

  /// The [limit] newest media items on the dives at [siteId], with their
  /// enrichment, for the strip on the site's dive photos card (issue #4502).
  /// Undated items come after dated ones.
  // stats-scope-exempt: a displayed gallery, which shows the media of
  // excluded dives like the logbook shows the dives themselves.
  Future<List<MediaItem>> getRecentMediaFromDivesAtSite(
    String siteId, {
    required int limit,
  }) async {
    try {
      final rows = await _db
          .customSelect(
            '''
        SELECT m.*, ${enrichmentSelectColumns(_db)}
        FROM media m
        LEFT JOIN media_enrichment e ON e.media_id = m.id
        WHERE m.dive_id IN (SELECT id FROM dives WHERE site_id = ?)
          AND m.file_type NOT IN ($_nonBrowsablePlaceholders)
        ORDER BY m.taken_at IS NULL, m.taken_at DESC, m.id DESC
        LIMIT ?
      ''',
            variables: [
              Variable.withString(siteId),
              ..._nonBrowsableVariables,
              Variable.withInt(limit),
            ],
          )
          .get();

      return [for (final row in rows) mediaItemFromJoinedRow(_db, row)];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get recent media from dives at site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
