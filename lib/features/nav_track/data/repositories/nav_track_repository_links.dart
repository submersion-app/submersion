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
  /// site/location into the route. A route with no site takes the dive's,
  /// even when it already has an anchor (#4851), and an anchor the diver
  /// placed is never overwritten (see [_siteAndAnchorToInherit]).
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
  }) => _linkTo(routeId, diveId, linkMode: linkMode);

  /// [link], where [previousDiveSiteId] is the site of the dive the route
  /// was just moved off ([relink]): a route still on that site took it from
  /// that dive, so it takes the new dive's instead.
  Future<bool> _linkTo(
    String routeId,
    String diveId, {
    required domain.NavTrackLinkMode linkMode,
    String? previousDiveSiteId,
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
          : await _siteAndAnchorToInherit(
              route,
              diveId,
              previousDiveSiteId: previousDiveSiteId,
            );
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
              anchorLatitude: inherited == null || !inherited.writeAnchor
                  ? const Value.absent()
                  : Value(inherited.anchor?.latitude),
              anchorLongitude: inherited == null || !inherited.writeAnchor
                  ? const Value.absent()
                  : Value(inherited.anchor?.longitude),
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
    // Read before the unlink: a route still on the old dive's site is taken
    // to have it from that dive (#4851).
    final previousDiveSiteId = await _siteIdOfDive(fromDiveId);
    await unlink(routeId, onlyFromDiveId: fromDiveId);
    return _linkTo(
      routeId,
      toDiveId,
      linkMode: linkMode,
      previousDiveSiteId: previousDiveSiteId,
    );
  }

  Future<String?> _siteIdOfDive(String diveId) =>
      (_db.selectOnly(_db.dives)
            ..addColumns([_db.dives.siteId])
            ..where(_db.dives.id.equals(diveId)))
          .map((row) => row.read(_db.dives.siteId))
          .getSingleOrNull();

  /// What linking [route] to [diveId] writes into its site and anchor, or
  /// null when the route keeps both as they are.
  ///
  /// The route takes the dive's site when it has none, or when its site is
  /// [previousDiveSiteId], the site of the dive it was moved off (#4851).
  /// A route keeps no record of where its site came from, so that site
  /// counts as the old dive's even when the diver picked the same one by
  /// hand: moving the route to a dive elsewhere then moves its site too,
  /// which is what the diver wants in all but that rare case. Any other
  /// site stays, and so does everything else.
  /// When the site changes, the anchor follows the new site's pin
  /// ([navTrackAnchorChangeForSite]), falling back to the dive's entry fix
  /// when the dive has no site; a site with no pin leaves the route
  /// unanchored, as an import does. An anchor the diver placed by hand is
  /// never moved.
  Future<({String? siteId, bool writeAnchor, GeoPoint? anchor})?>
  _siteAndAnchorToInherit(
    domain.NavTrack route,
    String diveId, {
    String? previousDiveSiteId,
  }) async {
    final ownSiteId = route.siteId;
    final siteFollowsDive =
        ownSiteId == null || ownSiteId == previousDiveSiteId;
    if (!siteFollowsDive) return null;
    final diveRow = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (diveRow == null) return null;
    final newSiteId = diveRow.siteId;
    final newSiteLocation = newSiteId == null
        ? null
        : (await _siteRepository.getSiteById(newSiteId))?.location;
    final oldSiteLocation = ownSiteId == null
        ? null
        : (await _siteRepository.getSiteById(ownSiteId))?.location;
    final change = navTrackAnchorChangeForSite(
      route.anchor,
      oldSiteLocation,
      newSiteLocation,
    );
    var anchor = change.anchor;
    final entryLat = diveRow.entryLatitude;
    final entryLon = diveRow.entryLongitude;
    if (change.write &&
        newSiteId == null &&
        entryLat != null &&
        entryLon != null) {
      anchor = GeoPoint(entryLat, entryLon);
    }
    return (
      siteId: newSiteId,
      // Nothing to write when the anchor stays unset.
      writeAnchor: change.write && anchor != route.anchor,
      anchor: anchor,
    );
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
  ///
  /// Given [onlyForDiveId], it does so only while the route is still on
  /// that dive, and answers false otherwise (gone, unlinked, or moved by a
  /// sync to another dive) without touching anything: a held change must
  /// not reorder another dive's routes (issue #4527). True once set.
  Future<bool> setPrimary(String routeId, {String? onlyForDiveId}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Read inside the write, so a sync cannot move the route between the
      // check and the demotions it decides.
      final demotedIds = await _db.transaction(() async {
        final route = await getById(routeId, includePoints: false);
        if (onlyForDiveId != null && route?.diveId != onlyForDiveId) {
          return null;
        }
        if (route == null) {
          throw ArgumentError.value(routeId, 'routeId', 'No such route');
        }
        final diveId = route.diveId;
        if (diveId == null) {
          throw StateError(
            'Route $routeId has no linked dive to be primary for',
          );
        }
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
      if (demotedIds == null) return false;
      // Every demoted route must be marked pending with the same timestamp
      // too, not only the newly primary one -- otherwise a sibling route's
      // stale isPrimary: true survives on another device until something
      // else touches that row, and that device keeps rendering the wrong
      // route as primary.
      await _markPending(routeId, now);
      for (final demotedId in demotedIds) {
        await _markPending(demotedId, now);
      }
      return true;
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
