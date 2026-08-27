import 'package:drift/drift.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Paginated, filtered, cross-dive media reads for the Media section.
///
/// Deliberately separate from MediaRepository (per-dive CRUD): this class
/// owns exactly one job — library queries. Pagination is keyset on the active
/// sort key plus id, so deep scroll positions stay flat-cost on large
/// libraries. Every sort key is coalesced to a non-null value; see
/// [_afterCursor] for why. Signature rows are always excluded;
/// dive-linked media is scoped to the given diver; unlinked and site-only
/// media is diver-global (matching the orphan sweep's view of the world).
///
/// Rows hydrate lean (no enrichment join) — grids do not render photo-time
/// depth/temp, and the detail surfaces that do already fetch it per dive.
class MediaLibraryRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  static final _log = LoggerService.forClass(MediaLibraryRepository);

  /// The library's date key: COALESCE(taken_at, created_at).
  ///
  /// This serves the fromDate/toDate FILTER BOUNDS and, when the active sort
  /// is dateTaken, the ordering. The two roles are deliberately separate:
  /// bounds must always compare dates, even when the page is ordered by name
  /// or size.
  Expression<int> get _dateKey =>
      coalesce<int>([_db.media.takenAt, _db.media.createdAt]);

  /// Filename key, falling back to file_path (NOT NULL) so the expression is
  /// total.
  Expression<String> get _nameKey =>
      coalesce<String>([_db.media.originalFilename, _db.media.filePath]);

  /// Size key. content_size_bytes is written only once the media store has
  /// hashed a row, so unhashed rows coalesce to -1 and sort as smallest.
  Expression<int> get _sizeKey =>
      coalesce<int>([_db.media.contentSizeBytes, const Constant(-1)]);

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
          _dateKey.isBiggerOrEqualValue(
            TripMediaScanner.toWallClockUtc(fromDate).millisecondsSinceEpoch,
          );
    }
    final toDate = filter.toDate;
    if (toDate != null) {
      where =
          where &
          _dateKey.isSmallerOrEqualValue(
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
      case null:
        break;
    }
    return where;
  }

  /// The keyset predicate for one page boundary.
  ///
  /// `key OP value OR (key = value AND id OP lastId)`, where `OP` follows the
  /// sort direction. The id tiebreaker is what keeps rows sharing a sort key
  /// from being dropped or repeated across a page boundary.
  ///
  /// [key] must be a coalesced (never NULL) expression. A NULL key makes
  /// every comparison here evaluate to NULL, which SQL treats as false, so
  /// the first page boundary that lands in a run of NULLs would match nothing
  /// and truncate the library silently.
  Expression<bool> _afterCursor<T extends Comparable<dynamic>>(
    Expression<T> key,
    T value,
    String lastId,
    SortDirection direction,
  ) {
    final descending = direction == SortDirection.descending;
    final beyond = descending
        ? key.isSmallerThanValue(value)
        : key.isBiggerThanValue(value);
    final tie = descending
        ? _db.media.id.isSmallerThanValue(lastId)
        : _db.media.id.isBiggerThanValue(lastId);
    return beyond | (key.equals(value) & tie);
  }

  /// The cursor value for [row] under [field]. Mirrors the COALESCE in the
  /// matching key expression: if these two ever disagree, pagination skips or
  /// repeats rows at the boundary.
  Object _cursorValue(MediaData row, MediaSortField field) => switch (field) {
    MediaSortField.dateTaken => row.takenAt ?? row.createdAt,
    MediaSortField.fileName => row.originalFilename ?? row.filePath,
    MediaSortField.fileSize => row.contentSizeBytes ?? -1,
  };

  /// The ordering expression for [field]. Typed loosely because OrderingTerm
  /// accepts any expression; the typed comparisons live in [_afterCursor].
  Expression<Object> _sortExpression(MediaSortField field) => switch (field) {
    MediaSortField.dateTaken => _dateKey,
    MediaSortField.fileName => _nameKey,
    MediaSortField.fileSize => _sizeKey,
  };

  /// One page of library entries for [diverId] (null = all divers), ordered
  /// by [sort] (newest first by default). Pass the previous page's
  /// [MediaLibraryPageResult.nextCursor] as [after] to continue.
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
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
            switch (sort.field) {
              MediaSortField.dateTaken => _afterCursor(
                _dateKey,
                after.sortKey as int,
                after.id,
                sort.direction,
              ),
              MediaSortField.fileName => _afterCursor(
                _nameKey,
                after.sortKey as String,
                after.id,
                sort.direction,
              ),
              MediaSortField.fileSize => _afterCursor(
                _sizeKey,
                after.sortKey as int,
                after.id,
                sort.direction,
              ),
            };
      }

      final mode = sort.direction == SortDirection.descending
          ? OrderingMode.desc
          : OrderingMode.asc;

      final query =
          _db.select(m).join([
              leftOuterJoin(d, d.id.equalsExp(m.diveId)),
              leftOuterJoin(s, s.id.equalsExp(d.siteId)),
            ])
            ..where(where)
            ..orderBy([
              OrderingTerm(expression: _sortExpression(sort.field), mode: mode),
              OrderingTerm(expression: m.id, mode: mode),
            ])
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
          sortKey: _cursorValue(last, sort.field),
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
  ///
  /// Built on `tableUpdates`, exactly like [MediaRepository.watchMediaChanges],
  /// and NOT on a watched COUNT query. A Drift query stream delivers its
  /// current value the moment it is listened to, and every consumer here feeds
  /// this stream to `ref.invalidateSelfWhen`. That combination is a live loop:
  /// build subscribes, the subscription immediately ticks, the tick invalidates
  /// the provider that just subscribed, the rebuild subscribes again. It ran
  /// one COUNT(*) over `media` per event-loop turn for as long as the Media
  /// section stayed open, which is enough to starve the UI isolate on a large
  /// library (#1175). `tableUpdates` only fires on a real write.
  ///
  /// Debounced on the same window as [MediaRepository.changeTickDebounce] so a
  /// sync's per-changeset commits -- or the media store worker stamping
  /// `remote_uploaded_at` row by row as it drains -- collapse into one reload
  /// instead of one per write.
  Stream<void> watchMediaChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.media))
      .debounce(MediaRepository.changeTickDebounce);
}
