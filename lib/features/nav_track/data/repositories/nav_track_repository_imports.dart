part of 'nav_track_repository.dart';

/// [NavTrackRepository]'s import writes: a route stored from its file, the
/// same route read again from a file (issue #4231), and the original file
/// and its markers read back.
///
/// On [_NavTrackRouteLinks] because an import pre-linked to a dive decides
/// its primary role the way a later link does.
mixin _NavTrackRouteImports on _NavTrackRouteLinks {
  SyncRepository get _syncRepository;
  Uuid get _uuid;

  /// Inserts a fully-parsed route in one write, optionally pre-linked to a
  /// dive (the review page's link proposal) and anchored to a site (the
  /// review page's site picker, or inherited from that dive).
  ///
  /// [diverId] is the importing (active) diver and owns an unlinked route.
  /// A pre-linked route belongs to its dive's diver instead, the same owner
  /// [link] gives a route linked afterward.
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
  ///
  /// An explicit [anchorLatitude]/[anchorLongitude] pair, given when the
  /// source file carries its own origin fix (a Suunto `DiveRouteOrigin`,
  /// issue #1445), is stored as-is and skips both fallbacks: the route's
  /// east/north are relative to that fix, not to the site or entry.
  ///
  /// [sourceMetadata] is stored as-is (issue #3047).
  ///
  /// [sourceFile] is the original file [points] were parsed from, stored
  /// byte for byte so the route can be derived again and exported unchanged
  /// (issue #4231). Null for a source that keeps none.
  Future<String> insertImportedRoute({
    required List<NavTrackPoint> points,
    required domain.NavTrackSource source,
    required String sourceRef,
    String? deviceName,
    String? name,
    String? diveId,
    String? siteId,
    String? equipmentId,
    String? diverId,
    double? anchorLatitude,
    double? anchorLongitude,
    Map<String, Object?>? sourceMetadata,
    Uint8List? sourceFile,
  }) async {
    try {
      if (points.length < 2) {
        throw ArgumentError.value(
          points.length,
          'points',
          'a track needs at least two samples',
        );
      }
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final stats = NavTrackStats.of(points);
      final isPrimary = diveId == null || await _shouldBePrimary(diveId);
      final explicitAnchor = anchorLatitude != null && anchorLongitude != null
          ? GeoPoint(anchorLatitude, anchorLongitude)
          : null;
      var anchor =
          explicitAnchor ??
          (siteId == null
              ? null
              : (await _siteRepository.getSiteById(siteId))?.location);
      // No site chosen on the review page but the route is being pre-linked
      // to a dive: fall back to the dive's own entry fix, the same
      // inheritance `link()`'s `_siteAndAnchorToInherit` already gives a
      // route linked afterward. Without this, whether a route ends up
      // anchored depends on which of the two otherwise-equivalent linking
      // paths (pre-link at import vs. link after the fact) the diver used.
      // A site the diver did choose wins even without coordinates: the
      // route stays unanchored rather than sitting at a different point.
      final diveRow = diveId == null
          ? null
          : await (_db.select(
              _db.dives,
            )..where((t) => t.id.equals(diveId))).getSingleOrNull();
      if (explicitAnchor == null &&
          anchor == null &&
          siteId == null &&
          diveRow != null) {
        final entryLat = diveRow.entryLatitude;
        final entryLon = diveRow.entryLongitude;
        if (entryLat != null && entryLon != null) {
          anchor = GeoPoint(entryLat, entryLon);
        }
      }
      await _db
          .into(_db.navTracks)
          .insert(
            NavTracksCompanion.insert(
              id: id,
              diveId: Value(diveId),
              diverId: Value(diveId == null ? diverId : diveRow?.diverId),
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
              durationSeconds: Value(stats.durationSeconds),
              anchorLatitude: Value(anchor?.latitude),
              anchorLongitude: Value(anchor?.longitude),
              sourceMetadata: Value(
                encodeNavTrackSourceMetadata(sourceMetadata),
              ),
              points: encodeNavTrackPoints(points),
              sourceFile: Value(_encodeSourceFileOrNull(id, sourceFile)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      // Without this the row's hlc stays NULL and the incremental export's
      // `hlc > watermark` filter excludes it forever (issue #1144's failure
      // mode, the reason sync_hlc_target_registration_test.dart exists).
      await _syncRepository.markRecordPending(
        entityType: NavTrackRepository.entityType,
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

  /// Replaces [routeId]'s data with a fresh parse of its file, keeping
  /// every setting the diver made (issue #4231): the dive link and primary
  /// role, the site, name, device, anchor and the whole correction.
  ///
  /// Writes [points], the statistics and recording window derived from
  /// them, and [sourceFile], the original file they came from. A non-null
  /// [sourceRef] also records the new file's name. Returns false when the
  /// route no longer exists, so nothing was updated.
  Future<bool> updateImportedData(
    String routeId, {
    required List<NavTrackPoint> points,
    required Uint8List sourceFile,
    String? sourceRef,
  }) async {
    try {
      if (points.length < 2) {
        throw ArgumentError.value(
          points.length,
          'points',
          'a track needs at least two samples',
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final stats = NavTrackStats.of(points);
      final rowsAffected =
          await (_db.update(
            _db.navTracks,
          )..where((t) => t.id.equals(routeId))).write(
            NavTracksCompanion(
              sourceRef: sourceRef == null
                  ? const Value.absent()
                  : Value(sourceRef),
              startTime: Value(points.first.timestamp * 1000),
              endTime: Value(points.last.timestamp * 1000),
              pointCount: Value(points.length),
              totalDistance: Value(stats.totalDistance),
              maxDepth: Value(stats.maxDepth),
              maxSpeed: Value(stats.maxSpeed),
              avgSpeed: Value(stats.avgSpeed),
              durationSeconds: Value(stats.durationSeconds),
              points: Value(encodeNavTrackPoints(points)),
              sourceFile: Value(_encodeSourceFileOrNull(routeId, sourceFile)),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) return false;
      await _markPending(routeId, now);
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update the data of nav track $routeId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The original file [routeId] was imported from (issue #4231), or null
  /// when the route keeps none or no longer exists.
  ///
  /// Throws [NavTrackSourceFileCodecException] when the stored blob cannot
  /// be read: an export must fail visibly rather than hand back nothing.
  Future<Uint8List?> getSourceFile(String routeId) async {
    final table = _db.navTracks;
    final row =
        await (_db.selectOnly(table)
              ..addColumns([table.sourceFile])
              ..where(table.id.equals(routeId)))
            .getSingleOrNull();
    final blob = row?.read(table.sourceFile);
    return blob == null ? null : decodeNavTrackSourceFile(blob);
  }

  /// The console's markers in [route]'s stored original file (issue
  /// #4231), for the views that draw them: none when the route keeps no
  /// file, is not an ENC route, carries no points to place them on, or its
  /// points no longer derive from that file ([NavTrackSourceMarkers]).
  ///
  /// Kept out of [getById] so that a list thumbnail or a map that hydrates
  /// a route's points never inflates and parses its file as well.
  Future<List<NavTrackMarker>> getMarkers(domain.NavTrack route) async {
    if (!route.hasSourceFile ||
        route.source != domain.NavTrackSource.seacraftEnc ||
        route.points.isEmpty) {
      return const [];
    }
    final table = _db.navTracks;
    final row =
        await (_db.selectOnly(table)
              ..addColumns([table.sourceFile])
              ..where(table.id.equals(route.id)))
            .getSingleOrNull();
    final blob = row?.read(table.sourceFile);
    if (blob == null) return const [];
    return NavTrackSourceMarkers.markersFor(
      routeId: route.id,
      blob: blob,
      points: route.points,
    );
  }

  /// [file] encoded for `source_file`, or null when there is none or it is
  /// over the codec's cap. The original file is a companion to the points,
  /// not the route itself: a file too large to keep must not fail an import
  /// or an update whose points are fine. Such a route simply has no file to
  /// export or read markers from.
  Uint8List? _encodeSourceFileOrNull(String routeId, Uint8List? file) {
    if (file == null) return null;
    try {
      return encodeNavTrackSourceFile(file);
    } on NavTrackSourceFileCodecException catch (e) {
      _log.warning('Not keeping the original file of nav track $routeId: $e');
      return null;
    }
  }
}
