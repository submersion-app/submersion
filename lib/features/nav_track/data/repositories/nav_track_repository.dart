import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart'
    as domain;
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';

/// Persistence for measured underwater routes (spec
/// 2026-09-10-underwater-nav-track-design.md, issues #1195, #1445).
///
/// Mirrors `GpsTrackRepository`'s shape: a synced blob-per-row table, one
/// write per import (routes arrive complete from a file, unlike a phone's
/// live-recorded GPS track, so there is no local buffer to checkpoint),
/// and tombstoned deletes so a route removed on one device stays removed
/// on every other.
class NavTrackRepository {
  static const String entityType = 'navTracks';

  /// Injectable seam so a test can hand in a fake site lookup instead of a
  /// real database-backed [SiteRepository]; production builds the default.
  NavTrackRepository({SiteRepository? siteRepository})
    : _siteRepository = siteRepository ?? SiteRepository();

  final SiteRepository _siteRepository;

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(NavTrackRepository);

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.navTracks));

  /// Inserts a fully-parsed route in one write, optionally pre-linked to a
  /// dive (the review page's link proposal) and anchored to a site (the
  /// review page's site picker, or inherited from that dive).
  ///
  /// When [siteId] resolves to a site with a location, that location is
  /// written straight into `anchorLatitude`/`anchorLongitude` (design spec
  /// 2026-09-10-underwater-nav-track-design.md, "Georeferencing": "The
  /// default anchor is the route's site pin ... so a freshly imported route
  /// already sits on the right stretch of shore before any correction").
  /// The stored anchor IS the site pin from the start; a later "Set start
  /// here" or a drag on the alignment page explicitly overrides it. No site
  /// chosen, or a site with no coordinates yet, leaves the anchor null, same
  /// as before.
  Future<String> insertImportedRoute({
    required List<NavTrackPoint> points,
    required domain.NavTrackSource source,
    required String sourceRef,
    String? deviceName,
    String? name,
    String? diveId,
    String? siteId,
    String? equipmentId,
  }) async {
    try {
      if (points.length < 2) {
        throw ArgumentError.value(
          points.length,
          'points',
          'a route needs at least two samples',
        );
      }
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final stats = NavTrackStats.of(points);
      final isPrimary = diveId == null || await _shouldBePrimary(diveId);
      final siteLocation = siteId == null
          ? null
          : (await _siteRepository.getSiteById(siteId))?.location;
      await _db
          .into(_db.navTracks)
          .insert(
            NavTracksCompanion.insert(
              id: id,
              diveId: Value(diveId),
              linkMode: Value(
                diveId == null
                    ? null
                    : domain.NavTrackLinkMode.manual.wireValue,
              ),
              isPrimary: Value(isPrimary),
              siteId: Value(siteId),
              source: source.wireValue,
              sourceRef: Value(sourceRef),
              deviceName: Value(deviceName),
              name: Value(name),
              equipmentId: Value(equipmentId),
              startTime: points.first.timestamp * 1000,
              endTime: points.last.timestamp * 1000,
              pointCount: points.length,
              totalDistance: Value(stats.totalDistance),
              maxDepth: Value(stats.maxDepth),
              maxSpeed: Value(stats.maxSpeed),
              avgSpeed: Value(stats.avgSpeed),
              anchorLatitude: Value(siteLocation?.latitude),
              anchorLongitude: Value(siteLocation?.longitude),
              points: encodeNavTrackPoints(points),
              createdAt: now,
              updatedAt: now,
            ),
          );
      // Without this the row's hlc stays NULL and the incremental export's
      // `hlc > watermark` filter excludes it forever (issue #1144's failure
      // mode, the reason sync_hlc_target_registration_test.dart exists).
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return id;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to insert imported nav track',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.NavTrack?> getById(
    String id, {
    bool includePoints = true,
  }) async {
    final row = await (_db.select(
      _db.navTracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row, includePoints: includePoints);
  }

  /// Routes linked to [diveId], primary first.
  Future<List<domain.NavTrack>> getForDive(
    String diveId, {
    bool includePoints = false,
  }) async {
    final rows =
        await (_db.select(_db.navTracks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
            .get();
    return [for (final r in rows) _toDomain(r, includePoints: includePoints)];
  }

  /// Every route with no dive link, most recently recorded first -- the
  /// routes area's own candidates for the match sweep and the manual link
  /// picker.
  Future<List<domain.NavTrack>> getUnlinked({
    bool includePoints = false,
  }) async {
    final rows =
        await (_db.select(_db.navTracks)
              ..where((t) => t.diveId.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
            .get();
    return [for (final r in rows) _toDomain(r, includePoints: includePoints)];
  }

  /// Every route for the routes area's own list, unlinked first and then
  /// most recently recorded within each group.
  Future<List<domain.NavTrack>> getAll({bool includePoints = false}) async {
    final rows = await (_db.select(
      _db.navTracks,
    )..orderBy([(t) => OrderingTerm.desc(t.startTime)])).get();
    final tracks = [
      for (final r in rows) _toDomain(r, includePoints: includePoints),
    ];
    tracks.sort((a, b) {
      final unlinkedCompare = (a.diveId == null ? 0 : 1).compareTo(
        b.diveId == null ? 0 : 1,
      );
      if (unlinkedCompare != 0) return unlinkedCompare;
      return b.startTime.compareTo(a.startTime);
    });
    return tracks;
  }

  /// Links [routeId] to [diveId]. The route becomes primary for that dive
  /// unless another route is already linked to it and primary -- "the
  /// first link sets it".
  ///
  /// Used by both the auto-match sweep and every manual link picker, so this
  /// is the one place to make linking inherit the dive's existing site and
  /// location as the route's own default anchor when the route does not
  /// already have one (design spec 2026-09-10-underwater-nav-track-design.md
  /// item 5; the schema's own doc comment on `siteId` already describes this
  /// as intended: "The dive site chosen at import (or taken from the linked
  /// dive)"). Deliberately the opposite direction from Decision 2 in the same
  /// spec, which forbids a route ever writing INTO the dive's entry/exit
  /// coordinates automatically -- this only ever reads the dive's EXISTING
  /// site/location into the route, and only when the route has neither a
  /// site nor an anchor of its own yet, so a route the diver already
  /// positioned is never overwritten.
  Future<void> link(
    String routeId,
    String diveId, {
    required domain.NavTrackLinkMode linkMode,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final isPrimary = await _shouldBePrimary(
        diveId,
        excludingRouteId: routeId,
      );
      final route = await getById(routeId, includePoints: false);
      final inherited = route == null
          ? null
          : await _siteAndAnchorToInherit(route, diveId);
      await (_db.update(
        _db.navTracks,
      )..where((t) => t.id.equals(routeId))).write(
        NavTracksCompanion(
          diveId: Value(diveId),
          linkMode: Value(linkMode.wireValue),
          isPrimary: Value(isPrimary),
          siteId: inherited == null
              ? const Value.absent()
              : Value(inherited.siteId),
          anchorLatitude: inherited?.anchor == null
              ? const Value.absent()
              : Value(inherited!.anchor!.latitude),
          anchorLongitude: inherited?.anchor == null
              ? const Value.absent()
              : Value(inherited!.anchor!.longitude),
          updatedAt: Value(now),
        ),
      );
      await _markPending(routeId, now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to link nav track $routeId to dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The dive's existing site/location to write into [route] as part of
  /// linking it to [diveId], or null when there is nothing to inherit or
  /// [route] already has a site or an anchor of its own (never overwritten).
  Future<({String? siteId, GeoPoint? anchor})?> _siteAndAnchorToInherit(
    domain.NavTrack route,
    String diveId,
  ) async {
    if (route.siteId != null || route.anchor != null) return null;
    final diveRow = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (diveRow == null) return null;
    if (diveRow.siteId != null) {
      final site = await _siteRepository.getSiteById(diveRow.siteId!);
      return (siteId: diveRow.siteId, anchor: site?.location);
    }
    final entryLat = diveRow.entryLatitude;
    final entryLon = diveRow.entryLongitude;
    if (entryLat != null && entryLon != null) {
      return (siteId: null, anchor: GeoPoint(entryLat, entryLon));
    }
    return null;
  }

  /// Unlinks [routeId] from whatever dive it was linked to. The recording
  /// itself, its correction, and its samples are untouched.
  Future<void> unlink(String routeId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.navTracks,
      )..where((t) => t.id.equals(routeId))).write(
        NavTracksCompanion(
          diveId: const Value(null),
          linkMode: const Value(null),
          isPrimary: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _markPending(routeId, now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to unlink nav track $routeId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Makes [routeId] the route a dive's 3D seascape draws, demoting every
  /// other route linked to the same dive.
  Future<void> setPrimary(String routeId) async {
    try {
      final route = await getById(routeId, includePoints: false);
      if (route == null) {
        throw ArgumentError.value(routeId, 'routeId', 'No such route');
      }
      final diveId = route.diveId;
      if (diveId == null) {
        throw StateError('Route $routeId has no linked dive to be primary for');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final demotedIds = await _db.transaction(() async {
        final demoted =
            await (_db.select(_db.navTracks)..where(
                  (t) =>
                      t.diveId.equals(diveId) &
                      t.id.equals(routeId).not() &
                      t.isPrimary.equals(true),
                ))
                .get();
        await (_db.update(_db.navTracks)..where(
              (t) => t.diveId.equals(diveId) & t.id.equals(routeId).not(),
            ))
            .write(
              NavTracksCompanion(
                isPrimary: const Value(false),
                updatedAt: Value(now),
              ),
            );
        await (_db.update(
          _db.navTracks,
        )..where((t) => t.id.equals(routeId))).write(
          NavTracksCompanion(
            isPrimary: const Value(true),
            updatedAt: Value(now),
          ),
        );
        return [for (final row in demoted) row.id];
      });
      // Every demoted route must be marked pending with the same timestamp
      // too, not only the newly primary one -- otherwise a sibling route's
      // stale isPrimary: true survives on another device until something
      // else touches that row, and that device keeps rendering the wrong
      // route as primary.
      await _markPending(routeId, now);
      for (final demotedId in demotedIds) {
        await _markPending(demotedId, now);
      }
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set nav track $routeId primary',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Writes a route's georeferencing and drift correction. Every field of
  /// [correction] is written, including nulls -- unlike `NavTrack.copyWith`,
  /// this is the one place a route's anchor or end target can be cleared.
  Future<void> updateCorrection(
    String routeId,
    NavTrackCorrection correction,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.navTracks,
      )..where((t) => t.id.equals(routeId))).write(
        NavTracksCompanion(
          anchorLatitude: Value(correction.anchor?.latitude),
          anchorLongitude: Value(correction.anchor?.longitude),
          endMode: Value(correction.endMode.wireValue),
          endLatitude: Value(correction.endPoint?.latitude),
          endLongitude: Value(correction.endPoint?.longitude),
          trustFraction: Value(correction.trustFraction),
          headingOffsetDeg: Value(correction.headingOffsetDeg),
          updatedAt: Value(now),
        ),
      );
      await _markPending(routeId, now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update the correction on nav track $routeId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Changes the dive site linked to [routeId] after import (unlike the
  /// import review page's site picker, which only ever sets it once).
  ///
  /// [anchor], when given, is written as the new anchor too. The caller
  /// decides whether to pass it: the safe rule (spec 2026-09-10-underwater-
  /// nav-track-design.md item 5) is that the anchor should follow the new
  /// site's pin only when the diver never moved the start point away from
  /// the old site's pin (the current anchor is unset, or still exactly
  /// equals the old site's stored location) -- never when they already
  /// corrected it by hand. Passing null leaves the stored anchor untouched
  /// either way.
  Future<void> setSite(
    String routeId,
    String? siteId, {
    GeoPoint? anchor,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.navTracks,
      )..where((t) => t.id.equals(routeId))).write(
        NavTracksCompanion(
          siteId: Value(siteId),
          anchorLatitude: anchor != null
              ? Value(anchor.latitude)
              : const Value.absent(),
          anchorLongitude: anchor != null
              ? Value(anchor.longitude)
              : const Value.absent(),
          updatedAt: Value(now),
        ),
      );
      await _markPending(routeId, now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to change the site on nav track $routeId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Renames [routeId], or clears its label back to the file name default
  /// when [name] is null.
  Future<void> rename(String routeId, String? name) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.navTracks)..where((t) => t.id.equals(routeId)))
          .write(NavTracksCompanion(name: Value(name), updatedAt: Value(now)));
      await _markPending(routeId, now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to rename nav track $routeId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Ids of every route currently linked to [diveId].
  ///
  /// Call this BEFORE the dive row is deleted and pass the result to
  /// [normalizeAfterDiveDeletion] after the delete completes: the `nav_tracks
  /// .dive_id` foreign key's own `SET NULL` action fires as part of the
  /// delete itself, so by the time the dive is gone there is no way to tell
  /// "was linked to this dive" from "was never linked" by querying
  /// `nav_tracks` alone.
  Future<List<String>> routeIdsLinkedToDive(String diveId) async {
    final rows = await (_db.select(
      _db.navTracks,
    )..where((t) => t.diveId.equals(diveId))).get();
    return [for (final row in rows) row.id];
  }

  /// Normalizes routes whose linked dive was just deleted.
  ///
  /// The `nav_tracks.dive_id` foreign key's `SET NULL` action already
  /// cleared `diveId` for these rows as part of the dive delete, but that is
  /// a single-column database-level action: it cannot also restore the
  /// schema invariant that `linkMode` is null exactly when `diveId` is null,
  /// reset `isPrimary` to its default, or mark the rows pending for sync.
  /// This does the rest, treating the dive-tombstone unlink as an ordinary
  /// route update rather than leaving it as a bare foreign-key side effect.
  Future<void> normalizeAfterDiveDeletion(List<String> routeIds) async {
    if (routeIds.isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.navTracks,
      )..where((t) => t.id.isIn(routeIds))).write(
        NavTracksCompanion(
          linkMode: const Value(null),
          isPrimary: const Value(true),
          updatedAt: Value(now),
        ),
      );
      for (final routeId in routeIds) {
        await _markPending(routeId, now);
      }
    } catch (e, stackTrace) {
      _log.error(
        'Failed to normalize nav tracks after dive deletion: $routeIds',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> delete(String routeId) async {
    try {
      await (_db.delete(
        _db.navTracks,
      )..where((t) => t.id.equals(routeId))).go();
      await _syncRepository.logDeletion(
        entityType: entityType,
        recordId: routeId,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete nav track $routeId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// True when no route other than [excludingRouteId] is already the
  /// primary route for [diveId] -- "the first link sets it".
  Future<bool> _shouldBePrimary(
    String diveId, {
    String? excludingRouteId,
  }) async {
    final rows =
        await (_db.select(_db.navTracks)..where((t) {
              final base = t.diveId.equals(diveId) & t.isPrimary.equals(true);
              return excludingRouteId == null
                  ? base
                  : base & t.id.equals(excludingRouteId).not();
            }))
            .get();
    return rows.isEmpty;
  }

  Future<void> _markPending(String routeId, int now) async {
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: routeId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Decodes a stored points blob, or null if it cannot be read.
  ///
  /// The blob is peer-supplied (nav_tracks syncs, and the points column
  /// rides as base64), so a malformed one is a data condition, not a
  /// programming error: every caller here degrades to a route with no
  /// points rather than propagating and taking the whole list down with
  /// one bad row.
  List<NavTrackPoint>? _decodePointsOrNull(String id, Uint8List blob) {
    try {
      return decodeNavTrackPoints(blob);
    } on NavTrackCodecException catch (e, stackTrace) {
      _log.error(
        'Unreadable points blob on nav track $id; reporting it with no points',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  domain.NavTrack _toDomain(NavTrackRow row, {required bool includePoints}) {
    return domain.NavTrack(
      id: row.id,
      diveId: row.diveId,
      linkMode: domain.NavTrackLinkMode.fromWireValue(row.linkMode),
      isPrimary: row.isPrimary,
      siteId: row.siteId,
      source: domain.NavTrackSource.fromWireValue(row.source),
      sourceRef: row.sourceRef,
      deviceName: row.deviceName,
      name: row.name,
      equipmentId: row.equipmentId,
      startTime: row.startTime,
      endTime: row.endTime,
      tzOffsetMinutes: row.tzOffsetMinutes,
      timeOffsetSeconds: row.timeOffsetSeconds,
      pointCount: row.pointCount,
      totalDistance: row.totalDistance,
      maxDepth: row.maxDepth,
      maxSpeed: row.maxSpeed,
      avgSpeed: row.avgSpeed,
      anchorLatitude: row.anchorLatitude,
      anchorLongitude: row.anchorLongitude,
      endMode: domain.NavTrackEndModeWire.fromWireValue(row.endMode),
      endLatitude: row.endLatitude,
      endLongitude: row.endLongitude,
      trustFraction: row.trustFraction,
      headingOffsetDeg: row.headingOffsetDeg,
      points: includePoints
          ? _decodePointsOrNull(row.id, row.points) ?? const []
          : const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
