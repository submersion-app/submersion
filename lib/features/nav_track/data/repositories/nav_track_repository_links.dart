part of 'nav_track_repository.dart';

/// [NavTrackRepository]'s dive links: linking a route to a dive, unlinking
/// it, and which of a dive's routes is its primary one.
mixin _NavTrackRouteLinks {
  AppDatabase get _db;
  SiteRepository get _siteRepository;
  LoggerService get _log;
  Future<void> _markPending(String routeId, int now);
  Future<domain.NavTrack?> getById(String id, {bool includePoints});
  Future<List<String>> _idsWhere(
    Expression<bool> Function($NavTracksTable t) filter, {
    GeneratedColumn<Object>? orderBy,
    int? limit,
  });

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
  /// Returns true when [routeId] was actually linked. False (not an
  /// exception) means the row was gone or already linked when this write
  /// landed, for example deleted or linked by hand after a caller read it
  /// as unlinked. A sweep can then tell a real link from a no-op instead of
  /// reporting success for a write that touched nothing.
  /// The write itself only matches an unlinked row, so an existing link is
  /// never overwritten; relinking goes through [unlink] first.
  Future<bool> link(
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
      // The route belongs to whoever logged the dive, so a buddy's route
      // linked to my dive becomes mine and an ownerless one gains an owner.
      final diveOwner =
          await (_db.selectOnly(_db.dives)
                ..addColumns([_db.dives.diverId])
                ..where(_db.dives.id.equals(diveId)))
              .map((row) => row.read(_db.dives.diverId))
              .getSingleOrNull();
      final rowsAffected =
          await (_db.update(
            _db.navTracks,
          )..where((t) => t.id.equals(routeId) & t.diveId.isNull())).write(
            NavTracksCompanion(
              diveId: Value(diveId),
              diverId: Value(diveOwner),
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
      if (rowsAffected == 0) return false;
      await _markPending(routeId, now);
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to link nav track $routeId to dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Moves [routeId] from [fromDiveId] onto [toDiveId], for a diver choosing a
  /// different dive: [link] alone never overwrites an existing link. [link]
  /// settles the rest as for any new link.
  ///
  /// Returns true when the route moved. False means it was no longer on
  /// [fromDiveId], for example a sync moved it first, and it stays where it is.
  Future<bool> relink(
    String routeId, {
    required String fromDiveId,
    required String toDiveId,
    required domain.NavTrackLinkMode linkMode,
  }) async {
    await unlink(routeId, onlyFromDiveId: fromDiveId);
    return link(routeId, toDiveId, linkMode: linkMode);
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
  ///
  /// With [onlyFromDiveId], the route is unlinked only while it is still on
  /// that dive. The check is part of the update itself, so a sync that moves
  /// the route to another dive just before this write cannot get it detached
  /// from that other dive; the call is then a no-op.
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) async {
    try {
      final route = await getById(routeId, includePoints: false);
      final diveId = route?.diveId;
      final now = DateTime.now().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(_db.navTracks)..where((t) {
                final byId = t.id.equals(routeId);
                return onlyFromDiveId == null
                    ? byId
                    : byId & t.diveId.equals(onlyFromDiveId);
              }))
              .write(
                NavTracksCompanion(
                  diveId: const Value(null),
                  linkMode: const Value(null),
                  isPrimary: const Value(true),
                  updatedAt: Value(now),
                ),
              );
      if (onlyFromDiveId != null && rowsAffected == 0) return;
      await _markPending(routeId, now);
      if (diveId != null) await _promoteSiblingIfNoPrimary(diveId, now);
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
        final demoted = await _idsWhere(
          (t) =>
              t.diveId.equals(diveId) &
              t.id.equals(routeId).not() &
              t.isPrimary.equals(true),
        );
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
        return demoted;
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

  /// True when no route other than [excludingRouteId] is already the
  /// primary route for [diveId] -- "the first link sets it".
  Future<bool> _shouldBePrimary(
    String diveId, {
    String? excludingRouteId,
  }) async {
    final primaries = await _idsWhere((t) {
      final base = t.diveId.equals(diveId) & t.isPrimary.equals(true);
      return excludingRouteId == null
          ? base
          : base & t.id.equals(excludingRouteId).not();
    });
    return primaries.isEmpty;
  }

  /// Promotes the earliest-recorded route still linked to [diveId] to
  /// primary, when unlinking or deleting a route has left the dive with
  /// siblings but none of them marked primary. Without this, a dive that
  /// still has a linked route can end up with no `isPrimary: true` row at
  /// all until a user happens to call [setPrimary] by hand.
  Future<void> _promoteSiblingIfNoPrimary(String diveId, int now) async {
    // Not getSingleOrNull: sync can leave a dive with two primaries (see
    // [getForDive]), and "any primary left" is all this needs to know.
    final stillPrimary = await _idsWhere(
      (t) => t.diveId.equals(diveId) & t.isPrimary.equals(true),
      limit: 1,
    );
    if (stillPrimary.isNotEmpty) return;
    final sibling = await _idsWhere(
      (t) => t.diveId.equals(diveId),
      orderBy: _db.navTracks.startTime,
      limit: 1,
    );
    if (sibling.isEmpty) return;
    final siblingId = sibling.single;
    await (_db.update(
      _db.navTracks,
    )..where((t) => t.id.equals(siblingId))).write(
      NavTracksCompanion(isPrimary: const Value(true), updatedAt: Value(now)),
    );
    await _markPending(siblingId, now);
  }
}
