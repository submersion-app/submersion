import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

/// Writes an underwater track page's editing sitting (issue #4527, phase 3,
/// plan 5): its changed values and its dive link, in one transaction and
/// one History entry labelled with the cards it changed.
class NavTrackEditSaveService {
  NavTrackEditSaveService(this._routes);

  final NavTrackRepository _routes;

  /// [anchorFromSite] is the anchor a site pick in the sitting moved
  /// ([navTrackAnchorFromSite]), taken back if that site cannot be set.
  ///
  /// Saves [apply] onto route [routeId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept.
  ///
  /// The row is written first, then a changed dive is linked, relinked or
  /// unlinked through the repository: linking takes the dive's owner, picks
  /// the primary route and gives a route with no site or anchor the dive's,
  /// and unlinking promotes a sibling. A site set in the same sitting is
  /// already in place, so linking inherits nothing over it. A dive chosen
  /// here wins over a link another device made meanwhile; one another
  /// device deleted meanwhile is not linked, nor is a site set that another
  /// device deleted meanwhile.
  ///
  /// Returns the route before and after, or null when nothing changed.
  /// Throws [StateError] when the route no longer exists.
  Future<({NavTrack before, NavTrack after})?> save({
    required String routeId,
    required NavTrack Function(NavTrack stored) apply,
    required Iterable<String> changedCardIds,
    ({GeoPoint? anchor})? anchorFromSite,
  }) => writeRecordSitting<NavTrack>(
    table: 'nav_tracks',
    recordId: routeId,
    changedCardIds: changedCardIds,
    read: () => _routes.getById(routeId, includePoints: false),
    apply: apply,
    write: (stored, merged) async {
      // A site another device deleted meanwhile is not set (the route keeps
      // the one stored), as a dive deleted meanwhile is not linked: the
      // sitting's other changes are saved.
      var siteId = merged.siteId;
      var correction = merged.correction;
      if (siteId != null &&
          siteId != stored.siteId &&
          !await _routes.siteExists(siteId)) {
        siteId = stored.siteId;
        // An anchor the pick moved to that site's pin goes back with it; one
        // placed by hand stays.
        if (anchorFromSite != null && merged.anchor == anchorFromSite.anchor) {
          correction = merged
              .withCorrection(
                NavTrackCorrection(
                  anchor: stored.anchor,
                  endMode: merged.endMode,
                  endPoint: merged.endPoint,
                  trustFraction: merged.trustFraction,
                  headingOffsetDeg: merged.headingOffsetDeg,
                  scaleFactor: merged.scaleFactor,
                ),
              )
              .correction;
        }
      }
      await _routes.writeEditedColumns(
        routeId,
        name: merged.name,
        siteId: siteId,
        equipmentId: merged.equipmentId,
        deviceName: merged.deviceName,
        correction: correction,
      );
      final from = stored.diveId;
      final to = merged.diveId;
      if (from == to) return;
      // A dive deleted by another device meanwhile is not linked, and the
      // route stays where it is; the sitting's other changes are saved.
      if (to != null && !await _routes.diveExists(to)) return;
      if (to == null) {
        await _routes.unlink(routeId, onlyFromDiveId: from);
      } else if (from == null) {
        await _routes.link(routeId, to, linkMode: NavTrackLinkMode.manual);
      } else {
        await _routes.relink(
          routeId,
          fromDiveId: from,
          toDiveId: to,
          linkMode: NavTrackLinkMode.manual,
        );
      }
    },
  );
}

final navTrackEditSaveServiceProvider = Provider<NavTrackEditSaveService>(
  (ref) => NavTrackEditSaveService(ref.watch(navTrackRepositoryProvider)),
);
