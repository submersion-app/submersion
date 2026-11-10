import 'package:drift/drift.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_library_group_order.dart';
import 'package:submersion/features/media/data/repositories/media_library_rows.dart';
import 'package:submersion/features/media/data/repositories/media_library_tile_markers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_grouping.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_placement_resolver.dart';

/// Paginated, filtered, cross-dive media reads for the Media section.
///
/// Deliberately separate from MediaRepository (per-dive CRUD): this class
/// owns exactly one job — library queries. Pagination is keyset on the active
/// sort key plus id, so deep scroll positions stay flat-cost on large
/// libraries. Every sort key is coalesced to a non-null value; see
/// [_afterCursor] for why. Signature and document rows are always excluded;
/// dive-linked media is scoped to the given diver; unlinked and site-only
/// media is diver-global (matching the orphan sweep's view of the world).
///
/// Rows hydrate lean (no enrichment join) — grids do not render photo-time
/// depth/temp, and the detail surfaces that do already fetch it per dive.
class MediaLibraryRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  static final _log = LoggerService.forClass(MediaLibraryRepository);

  /// Rows in one [getPage] unless the caller asks for more.
  static const int pageSize = 60;

  /// The library's date key: COALESCE(taken_at, created_at).
  ///
  /// This serves the fromDate/toDate FILTER BOUNDS and, when the active sort
  /// is dateTaken, the ordering. The two roles are deliberately separate:
  /// bounds must always compare dates, even when the page is ordered by name
  /// or size.
  Expression<int> get _dateKey =>
      coalesce<int>([_db.media.takenAt, _db.media.createdAt]);

  /// Filename key, falling back to file_path (NOT NULL) so the expression is
  /// total. NOCASE so "IMG_1.jpg" and "img_2.jpg" sort together (#2038); the
  /// cursor comparisons in [_afterCursor] use this same expression, so page
  /// boundaries agree with the ORDER BY.
  Expression<String> get _nameKey => coalesce<String>([
    _db.media.originalFilename,
    _db.media.filePath,
  ]).collate(Collate.noCase);

  /// Size key. content_size_bytes is written only once the media store has
  /// hashed a row, so unhashed rows coalesce to -1 and sort as smallest.
  Expression<int> get _sizeKey =>
      coalesce<int>([_db.media.contentSizeBytes, const Constant(-1)]);

  /// Which rows are library rows at all (see [MediaLibraryRows]).
  MediaLibraryRows get _rows => MediaLibraryRows(_db);

  /// A row of the ordinary library views: no signature, document or gear
  /// photo.
  Expression<bool> get _galleryRow => _rows.galleryRow;

  /// Dive-linked rows belong to their dive's diver; unlinked and site-only
  /// rows are diver-global. Needs `dives` joined on `media.dive_id`.
  Expression<bool> _diverScope(String? diverId) => diverId == null
      ? const Constant(true)
      : _db.media.diveId.isNull() | _db.dives.diverId.equals(diverId);

  /// Rows attached to any of [kinds] (issue #4224), by the row's own links in
  /// [MediaAttachmentKind]'s precedence, the one `groupByDive` and the By
  /// dive group key use. Reads only media columns, so it adds no join.
  Expression<bool> _attachedToFacet(Set<MediaAttachmentKind> kinds) {
    final m = _db.media;
    final noDive = m.diveId.isNull();
    final noSite = m.siteId.isNull();
    return [
      for (final kind in kinds)
        switch (kind) {
          MediaAttachmentKind.dive => m.diveId.isNotNull(),
          MediaAttachmentKind.site => noDive & m.siteId.isNotNull(),
          MediaAttachmentKind.equipment =>
            noDive & noSite & m.equipmentId.isNotNull(),
          MediaAttachmentKind.unlinked =>
            noDive & noSite & m.equipmentId.isNull(),
        },
    ].reduce((a, b) => a | b);
  }

  /// Any of the selected buddies, or the viewing diver's own Me tags
  /// (issue #1745). EXISTS for the same reason as the tag facet: a photo
  /// with two of them comes back once. Me is one diver even when the
  /// library shows every profile ([_meDiverId]). When Me is off and none of
  /// the selected buddies
  /// still exists for this diver (an album outliving them, or naming
  /// another profile's buddy), the facet is dropped rather than matching
  /// nothing, as the tag facet does.
  Expression<bool> _peopleFacet(String? diverId, MediaLibraryFilter filter) {
    final m = _db.media;
    final p = _db.mediaPeople;
    final b = _db.buddies;
    final buddyIds = filter.buddyIds;
    final me = filter.includeMe
        ? p.diverId.equalsExp(_meDiverId(diverId))
        : const Constant<bool>(false);
    // Only the viewing diver's own buddies count (spec decision 9): an
    // album is shared by every profile, and another profile's buddy must
    // neither match that profile's tags nor keep the facet alive.
    Expression<bool> ownBuddy(Expression<bool> ids) => diverId == null
        ? ids
        : ids &
              p.buddyId.isInQuery(
                _db.selectOnly(b)
                  ..addColumns([b.id])
                  ..where(b.diverId.equals(diverId)),
              );
    final person = buddyIds.isEmpty
        ? me
        : (ownBuddy(p.buddyId.isIn(buddyIds)) | me);
    final tagged = existsQuery(
      _db.selectOnly(p)
        ..addColumns([p.id])
        ..where(p.mediaId.equalsExp(m.id) & person),
    );
    if (filter.includeMe) return tagged;
    final anySelectedBuddyExists = existsQuery(
      _db.selectOnly(b)
        ..addColumns([b.id])
        ..where(
          b.id.isIn(buddyIds) &
              (diverId == null
                  ? const Constant(true)
                  : b.diverId.equals(diverId)),
        ),
    );
    return anySelectedBuddyExists.not() | tagged;
  }

  /// The diver "Me" names: [diverId] while it exists, else the default
  /// diver, else the oldest, the same fallback
  /// `validatedCurrentDiverIdProvider` gives the tagging side, so the
  /// filter and the tags agree on who Me is.
  Expression<String> _meDiverId(String? diverId) {
    final d = _db.divers;
    Expression<String> first(Expression<bool> where) =>
        subqueryExpression<String>(
          _db.selectOnly(d)
            ..addColumns([d.id])
            ..where(where)
            ..orderBy([OrderingTerm.asc(d.createdAt)])
            ..limit(1),
        );
    return coalesce([
      if (diverId != null) first(d.id.equals(diverId)),
      first(d.isDefault.equals(true)),
      first(const Constant(true)),
    ]);
  }

  /// The ids of [tripId]'s valid side trips, whose photos the trip shows too
  /// (issue #3658). The rule of `side_trip_sql.dart`: the parent has no
  /// parent of its own and is not the side trip itself.
  BaseSelectStatement _sideTripIds(String tripId) {
    final side = _db.alias(_db.trips, 'side');
    final parent = _db.alias(_db.trips, 'parent');
    return (_db.selectOnly(side).join([
        innerJoin(parent, parent.id.equalsExp(side.parentTripId)),
      ])
      ..addColumns([side.id])
      ..where(
        side.parentTripId.equals(tripId) &
            parent.parentTripId.isNull() &
            side.id.equalsExp(parent.id).not(),
      ));
  }

  Expression<bool> _baseWhere(String? diverId, MediaLibraryFilter filter) {
    final m = _db.media;
    final d = _db.dives;

    Expression<bool> where =
        _rows.forFilter(filter, diverId) & _diverScope(diverId);
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
      where =
          where &
          (d.tripId.equals(tripId) | d.tripId.isInQuery(_sideTripIds(tripId)));
    }
    final speciesId = filter.speciesId;
    if (speciesId != null) {
      // Correlated EXISTS rather than a join: a photo tagged with several
      // species must still come back once.
      final ms = _db.mediaSpecies;
      where =
          where &
          existsQuery(
            _db.selectOnly(ms)
              ..addColumns([ms.id])
              ..where(
                ms.mediaId.equalsExp(m.id) & ms.speciesId.equals(speciesId),
              ),
          );
    }
    final tagIds = filter.tagIds;
    if (tagIds.isNotEmpty) {
      // Any of the tags (issue #1970). EXISTS for the same reason as the
      // species facet: a photo carrying two of them must come back once.
      // A tag that no longer exists (a saved album outliving it) has no
      // links, so it is ignored among others; when none of the selected
      // tags exists the facet is dropped rather than matching nothing.
      final mt = _db.mediaTags;
      final t = _db.tags;
      final anySelectedTagExists = existsQuery(
        _db.selectOnly(t)
          ..addColumns([t.id])
          ..where(t.id.isIn(tagIds)),
      );
      where =
          where &
          (anySelectedTagExists.not() |
              existsQuery(
                _db.selectOnly(mt)
                  ..addColumns([mt.id])
                  ..where(mt.mediaId.equalsExp(m.id) & mt.tagId.isIn(tagIds)),
              ));
    }
    if (filter.hasPeople) {
      where = where & _peopleFacet(diverId, filter);
    }
    if (filter.attachedTo.isNotEmpty) {
      where = where & _attachedToFacet(filter.attachedTo);
    }
    // The cleanup facets (issue #4148) negate the tile markers' own SQL, so
    // a row shows under each exactly when its tile lacks that marker.
    if (filter.noPeople) {
      where = where & LibraryTileMarkers.hasPeople.not();
    }
    if (filter.notPlacedInDive) {
      // Only dive rows: a row with no dive cannot be placed in one.
      where =
          where & m.diveId.isNotNull() & LibraryTileMarkers.hasTimeInDive.not();
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

  /// The keyset predicate across a grouped page's leading [keys] and then
  /// [sortAfter], the sort key's own predicate: a row is past the cursor
  /// when it is in a later group, or in the cursor's group and past it by
  /// [sortAfter]. With no keys this is [sortAfter] itself.
  ///
  /// A cursor from a walk under a different grouping cannot be continued
  /// here (it holds the wrong keys), so it is refused rather than read as
  /// some other group.
  Expression<bool> _afterGroups(
    List<LibraryGroupKey> keys,
    MediaLibraryCursor after,
    Expression<bool> sortAfter,
  ) {
    if (after.groupKeys.length != keys.length) {
      throw ArgumentError.value(
        after,
        'after',
        'cursor carries ${after.groupKeys.length} group keys, '
            'the page orders by ${keys.length}',
      );
    }
    Expression<bool> result = sortAfter;
    for (var i = keys.length - 1; i >= 0; i--) {
      final value = after.groupKeys[i];
      result = keys[i].after(value) | (keys[i].equalTo(value) & result);
    }
    return result;
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
  ///
  /// A [grouping] orders by the group first and by [sort] within each group,
  /// so a grouped view gets every group in one run (issue #4268). Pass the
  /// same grouping for every page of one walk: the cursor is only meaningful
  /// under the order that produced it.
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
    MediaLibraryGrouping grouping = MediaLibraryGrouping.none,
    MediaLibraryCursor? after,
    int limit = pageSize,
  }) async {
    try {
      final m = _db.media;
      final d = _db.dives;
      final s = _db.diveSites;
      // The row's own site and equipment links, for the by-dive view's
      // groups of media attached to no dive (issue #4149).
      final attached = _db.alias(_db.diveSites, 'attached_site');
      final e = _db.equipment;

      final groupKeys = libraryGroupKeys(
        grouping.forSort(sort.field),
        db: _db,
        dateDescending: groupsNewestFirst(sort.field, sort.direction),
        dateKey: _dateKey,
        dives: d,
        attachedSites: attached,
        equipment: e,
      );

      Expression<bool> where = _baseWhere(diverId, filter);
      if (after != null) {
        final sortAfter = switch (sort.field) {
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
        where = where & _afterGroups(groupKeys, after, sortAfter);
      }

      final mode = sort.direction == SortDirection.descending
          ? OrderingMode.desc
          : OrderingMode.asc;

      final query =
          _db.select(m).join([
              leftOuterJoin(d, d.id.equalsExp(m.diveId)),
              leftOuterJoin(s, s.id.equalsExp(d.siteId)),
              leftOuterJoin(attached, attached.id.equalsExp(m.siteId)),
              leftOuterJoin(e, e.id.equalsExp(m.equipmentId)),
            ])
            ..addColumns([
              for (final key in groupKeys) key.expression,
              ...LibraryTileMarkers.all,
            ])
            ..where(where)
            ..orderBy([
              for (final key in groupKeys) key.ordering,
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
          attachedSiteName: row.readTableOrNull(attached)?.name,
          attachedEquipmentName: row.readTableOrNull(e)?.name,
          hasPeople: row.read(LibraryTileMarkers.hasPeople) ?? false,
          hasSpecies: row.read(LibraryTileMarkers.hasSpecies) ?? false,
          hasTimeInDive: row.read(LibraryTileMarkers.hasTimeInDive) ?? false,
        );
      }).toList();

      MediaLibraryCursor? next;
      if (hasMore && entries.isNotEmpty) {
        final lastRow = visible.last;
        final last = lastRow.readTable(m);
        next = MediaLibraryCursor(
          sortKey: _cursorValue(last, sort.field),
          id: last.id,
          groupKeys: [for (final key in groupKeys) key.readFrom(lastRow)],
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
  /// browse-by-source list). Signatures and documents are excluded, as
  /// everywhere else in the library, so each count matches the grid it
  /// opens.
  Future<Map<MediaSourceType, int>> countBySourceType() async {
    final m = _db.media;
    final count = countAll();
    final query = _db.selectOnly(m)
      ..addColumns([m.sourceType, count])
      ..where(_galleryRow)
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

  /// Gallery rows whose persisted orphan flag is set. Backs the badge on the
  /// Media section's Library tab, so like the Missing filter it leaves
  /// documents out.
  Future<int> countMissing() async {
    final m = _db.media;
    final count = countAll(filter: m.isOrphaned.equals(true) & _galleryRow);
    final row = await (_db.selectOnly(m)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Every missing row in [diverId]'s scope, documents included, for the
  /// repair wizard and the watched-folder scanner.
  ///
  /// Not [getPage] with the missing filter: that is the gallery's view and
  /// leaves documents out (#3052), but a moved invoice needs relinking just
  /// as much as a moved photo. Signatures stay out, as they do everywhere.
  /// Unpaged because both callers want the whole backlog at once.
  Future<List<MediaItem>> getMissingRows({required String? diverId}) async {
    try {
      final m = _db.media;
      final d = _db.dives;
      final query =
          _db.select(m).join([
              leftOuterJoin(d, d.id.equalsExp(m.diveId), useColumns: false),
            ])
            ..where(
              m.fileType.isNotIn(kSignatureFileTypes) &
                  m.isOrphaned.equals(true) &
                  _diverScope(diverId),
            )
            ..orderBy([OrderingTerm.desc(_dateKey), OrderingTerm.desc(m.id)]);
      final rows = await query.get();
      return rows.map((row) => mediaItemFromRow(row.readTable(m))).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get missing media rows',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Photo and video rows only: documents have nothing to show on a map and
  /// signatures are never library rows. Subsumes [_galleryRow].
  Expression<bool> get _mappable =>
      _db.media.fileType.isIn(const ['photo', 'video']);

  /// Every in-scope row that can be placed on the map, in the timeline's
  /// order (date taken ascending, then id).
  ///
  /// Unpaged by design: the cluster layer needs the whole located set at
  /// once. Sites are joined twice, through the dive and through the row's
  /// own site link, because site-attached media (issue #959) has no dive.
  /// The four coordinate pairs are fetched raw and resolved in Dart by
  /// [resolveMediaPlacement] so the plausibility rule lives in one place.
  Future<List<MediaMapPoint>> getMapPoints({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    try {
      final m = _db.media;
      final d = _db.dives;
      final s = _db.diveSites;
      final attached = _db.alias(_db.diveSites, 'attached_site');

      final where =
          _baseWhere(diverId, filter) &
          _mappable &
          (m.latitude.isNotNull() |
              d.entryLatitude.isNotNull() |
              s.latitude.isNotNull() |
              attached.latitude.isNotNull());

      final query =
          _db.select(m).join([
              leftOuterJoin(d, d.id.equalsExp(m.diveId)),
              leftOuterJoin(s, s.id.equalsExp(d.siteId)),
              leftOuterJoin(attached, attached.id.equalsExp(m.siteId)),
            ])
            ..where(where)
            ..orderBy([OrderingTerm.asc(_dateKey), OrderingTerm.asc(m.id)]);

      final rows = await query.get();
      final points = <MediaMapPoint>[];
      for (final row in rows) {
        final mediaRow = row.readTable(m);
        final diveRow = row.readTableOrNull(d);
        final siteRow = row.readTableOrNull(s);
        final attachedRow = row.readTableOrNull(attached);

        final resolved = resolveMediaPlacement(
          ownLatitude: mediaRow.latitude,
          ownLongitude: mediaRow.longitude,
          diveEntryLatitude: diveRow?.entryLatitude,
          diveEntryLongitude: diveRow?.entryLongitude,
          diveSiteLatitude: siteRow?.latitude,
          diveSiteLongitude: siteRow?.longitude,
          attachedSiteLatitude: attachedRow?.latitude,
          attachedSiteLongitude: attachedRow?.longitude,
        );
        if (resolved == null) continue;

        // A site placement is labelled with the site the item sits at; a GPS
        // placement takes the nearest context, the dive's site first.
        final label = resolved.placement == MediaPlacement.attachedSite
            ? attachedRow?.name
            : siteRow?.name ?? attachedRow?.name;
        points.add(
          MediaMapPoint(
            entry: MediaLibraryEntry(
              item: mediaItemFromRow(mediaRow),
              diveNumber: diveRow?.diveNumber,
              // Wall-clock-as-UTC, exactly as getPage hydrates it.
              diveDateTime: diveRow == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      diveRow.diveDateTime,
                      isUtc: true,
                    ),
              siteName: label,
            ),
            point: resolved.point,
            placement: resolved.placement,
            placeLabel: label,
          ),
        );
      }
      return points;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media map points',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// How many photo and video rows the grid would show for this scope. The
  /// map's "without a location" count is this minus [getMapPoints].length.
  Future<int> countInScope({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    final m = _db.media;
    final d = _db.dives;
    final count = countAll();
    final query =
        _db.selectOnly(m).join([
            leftOuterJoin(d, d.id.equalsExp(m.diveId), useColumns: false),
          ])
          ..addColumns([count])
          ..where(_baseWhere(diverId, filter) & _mappable);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Emits whenever anything that can move a map point, or change which
  /// points are in scope, changes: the media row itself, a dive's entry fix,
  /// a site's coordinates, or a species, tag or people tag (each filter is
  /// an EXISTS over its link table), or a time in the dive (the "not placed"
  /// facet's EXISTS over `media_enrichment`), or which gear an Equipment pick
  /// may show (`equipment`, `equipment_shares`). Built and debounced exactly like
  /// [watchMediaChanges]; see its notes on why a `tableUpdates` stream and
  /// not a watched query.
  Stream<void> watchMapChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _db.media,
          _db.dives,
          _db.diveSites,
          _db.mediaSpecies,
          _db.mediaTags,
          _db.mediaPeople,
          _db.mediaEnrichment,
          _db.equipment,
          _db.equipmentShares,
        ]),
      )
      .debounce(MediaRepository.changeTickDebounce);

  /// Emits whenever the media table, or a photo's tags, change (a tag edit
  /// can move a row into or out of a tag-filtered library, issue #1970).
  /// Deliberately coarse: consumers re-read rather than patching rows (per
  /// the Media section spec's invalidation-storm avoidance).
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
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _db.media,
          _db.mediaTags,
          _db.mediaPeople,
        ]),
      )
      .debounce(MediaRepository.changeTickDebounce);

  /// [watchMediaChanges] plus the tables only the library grid reads, so a
  /// row leaves, joins or changes on the page without a media row being
  /// written: `media_species` is the species filter's EXISTS, `trips` holds
  /// the side-trip links its trip filter takes in (issue #3658), `dives` and
  /// `dive_sites` give the trip and site filters, each row's dive header and
  /// the name of the site a dive-less row is attached to, `equipment` names
  /// an equipment-attached row's group (issue #4149), `equipment_shares`
  /// decides whose gear photos an Equipment pick shows (issue #3355), and
  /// `tags`, `buddies`
  /// and `divers` decide whether a facet applies at all
  /// and who Me names. Deleting a tag or buddy already ticks through its
  /// cascade; these catch one arriving late or changing owner.
  /// `media_enrichment` decides each tile's time-in-dive marker (issue
  /// #4218), which the enricher writes without touching the media row.
  Stream<void> watchLibraryChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _db.media,
          _db.mediaTags,
          _db.mediaPeople,
          _db.mediaSpecies,
          _db.mediaEnrichment,
          _db.trips,
          _db.dives,
          _db.diveSites,
          _db.equipment,
          _db.equipmentShares,
          _db.tags,
          _db.buddies,
          _db.divers,
        ]),
      )
      .debounce(MediaRepository.changeTickDebounce);
}
