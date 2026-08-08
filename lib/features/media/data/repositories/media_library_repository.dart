import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Source types that live at library level by design (subscription feeds and
/// URL media): they are never "unlinked" problems and never orphan-swept.
const List<String> kLibraryLevelSourceTypes = ['networkUrl', 'manifestEntry'];

/// Paginated, filtered, cross-dive media reads for the Media section.
///
/// Deliberately separate from MediaRepository (per-dive CRUD): this class
/// owns exactly one job — library queries. Pagination is keyset on
/// (COALESCE(taken_at, created_at) DESC, id DESC) so deep scroll positions
/// stay flat-cost on large libraries. Signature rows are always excluded;
/// dive-linked media is scoped to the given diver; unlinked and site-only
/// media is diver-global (matching the orphan sweep's view of the world).
///
/// Rows hydrate lean (no enrichment join) — grids do not render photo-time
/// depth/temp, and the detail surfaces that do already fetch it per dive.
class MediaLibraryRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  static final _log = LoggerService.forClass(MediaLibraryRepository);

  Expression<int> get _sortKey =>
      coalesce<int>([_db.media.takenAt, _db.media.createdAt]);

  /// Signatures never appear in the library, in any spelling.
  Expression<bool> get _notSignature =>
      _db.media.fileType.isNotIn(kSignatureFileTypes);

  Expression<bool> _baseWhere(String? diverId, MediaLibraryFilter filter) {
    final m = _db.media;
    final d = _db.dives;

    Expression<bool> where = _notSignature;
    if (diverId != null) {
      where = where & (m.diveId.isNull() | d.diverId.equals(diverId));
    }
    final type = filter.mediaType;
    if (type != null) {
      where = where & m.fileType.equals(mediaTypeToDbString(type));
    }
    final diveId = filter.diveId;
    if (diveId != null) {
      where = where & m.diveId.equals(diveId);
    }
    final siteId = filter.siteId;
    if (siteId != null) {
      where = where & (d.siteId.equals(siteId) | m.siteId.equals(siteId));
    }
    final tripId = filter.tripId;
    if (tripId != null) {
      where = where & d.tripId.equals(tripId);
    }
    // taken_at is stored as wall-clock-as-UTC millis, so a bound picked in
    // local time has to be normalised the same way before it can be
    // compared -- otherwise the window slides by the host's UTC offset.
    // TripMediaScanner does exactly this for its trip window bounds.
    final fromDate = filter.fromDate;
    if (fromDate != null) {
      where =
          where &
          _sortKey.isBiggerOrEqualValue(
            TripMediaScanner.toWallClockUtc(fromDate).millisecondsSinceEpoch,
          );
    }
    final toDate = filter.toDate;
    if (toDate != null) {
      where =
          where &
          _sortKey.isSmallerOrEqualValue(
            TripMediaScanner.toWallClockUtc(toDate).millisecondsSinceEpoch,
          );
    }
    final sourceType = filter.sourceType;
    if (sourceType != null) {
      where = where & m.sourceType.equals(sourceType.name);
    }
    switch (filter.health) {
      case MediaHealthFilter.missing:
        where = where & m.isOrphaned.equals(true);
      case MediaHealthFilter.unlinked:
        where =
            where &
            m.diveId.isNull() &
            m.siteId.isNull() &
            m.sourceType.isNotIn(kLibraryLevelSourceTypes);
      case null:
        break;
    }
    return where;
  }

  /// One page of library entries for [diverId] (null = all divers), newest
  /// first. Pass the previous page's [MediaLibraryPageResult.nextCursor] as
  /// [after] to continue.
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    MediaLibraryCursor? after,
    int limit = 60,
  }) async {
    try {
      final m = _db.media;
      final d = _db.dives;
      final s = _db.diveSites;

      Expression<bool> where = _baseWhere(diverId, filter);
      if (after != null) {
        where =
            where &
            (_sortKey.isSmallerThanValue(after.sortKey) |
                (_sortKey.equals(after.sortKey) &
                    m.id.isSmallerThanValue(after.id)));
      }

      final query =
          _db.select(m).join([
              leftOuterJoin(d, d.id.equalsExp(m.diveId)),
              leftOuterJoin(s, s.id.equalsExp(d.siteId)),
            ])
            ..where(where)
            ..orderBy([OrderingTerm.desc(_sortKey), OrderingTerm.desc(m.id)])
            ..limit(limit + 1);

      final rows = await query.get();
      final hasMore = rows.length > limit;
      final visible = hasMore ? rows.sublist(0, limit) : rows;

      final entries = visible.map((row) {
        final mediaRow = row.readTable(m);
        final diveRow = row.readTableOrNull(d);
        final siteRow = row.readTableOrNull(s);
        return MediaLibraryEntry(
          item: mediaItemFromRow(mediaRow),
          diveNumber: diveRow?.diveNumber,
          // dive_date_time is wall-clock-as-UTC, exactly as
          // DiveRepositoryImpl hydrates it. Reading it as a local instant
          // shifts every group header by the host's UTC offset.
          diveDateTime: diveRow == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  diveRow.diveDateTime,
                  isUtc: true,
                ),
          siteName: siteRow?.name,
        );
      }).toList();

      MediaLibraryCursor? next;
      if (hasMore && entries.isNotEmpty) {
        final last = visible.last.readTable(m);
        next = MediaLibraryCursor(
          sortKey: last.takenAt ?? last.createdAt,
          id: last.id,
        );
      }
      return MediaLibraryPageResult(entries: entries, nextCursor: next);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media library page',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Rows attached to neither a dive nor a site, excluding signatures and
  /// library-level source types. Backs the Unlinked sidebar badge.
  Future<int> countUnlinked() async {
    final m = _db.media;
    final count = countAll(
      filter:
          m.diveId.isNull() &
          m.siteId.isNull() &
          _notSignature &
          m.sourceType.isNotIn(kLibraryLevelSourceTypes),
    );
    final row = await (_db.selectOnly(m)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// How many library rows each source type holds (Media section Phase 5's
  /// browse-by-source list). Signatures are excluded, as everywhere else in
  /// the library.
  Future<Map<MediaSourceType, int>> countBySourceType() async {
    final m = _db.media;
    final count = countAll();
    final query = _db.selectOnly(m)
      ..addColumns([m.sourceType, count])
      ..where(_notSignature)
      ..groupBy([m.sourceType]);
    final rows = await query.get();
    final result = <MediaSourceType, int>{};
    for (final row in rows) {
      final type = MediaSourceType.fromString(row.read(m.sourceType));
      if (type == null) continue;
      result[type] = row.read(count) ?? 0;
    }
    return result;
  }

  /// Rows whose persisted orphan flag is set. Backs the Missing sidebar
  /// badge.
  Future<int> countMissing() async {
    final m = _db.media;
    final count = countAll(filter: m.isOrphaned.equals(true) & _notSignature);
    final row = await (_db.selectOnly(m)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Emits whenever the media table changes. Deliberately coarse: consumers
  /// reload page one rather than patching rows (per the Media section spec's
  /// invalidation-storm avoidance).
  Stream<void> watchMediaChanges() {
    final m = _db.media;
    final count = countAll();
    return (_db.selectOnly(m)..addColumns([count])).watchSingle().map((_) {});
  }
}
