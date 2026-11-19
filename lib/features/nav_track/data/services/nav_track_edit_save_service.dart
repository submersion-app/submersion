import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

/// Writes an underwater track page's editing sitting (issue #4527, phase 3,
/// plan 5): its changed values and its dive link, in one transaction and
/// one History entry labelled with the cards it changed.
class NavTrackEditSaveService {
  NavTrackEditSaveService(this._routes);

  final NavTrackRepository _routes;

  /// Saves [apply] onto route [routeId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept.
  ///
  /// The row is written first, then a changed dive is linked, relinked or
  /// unlinked through the repository: linking takes the dive's owner, picks
  /// the primary route and gives a route with no site or anchor the dive's,
  /// and unlinking promotes a sibling. A site set in the same sitting is
  /// already in place, so linking inherits nothing over it. A dive chosen
  /// here wins over a link another device made meanwhile.
  ///
  /// Returns the route before and after, or null when nothing changed.
  /// Throws [StateError] when the route no longer exists.
  Future<({NavTrack before, NavTrack after})?> save({
    required String routeId,
    required NavTrack Function(NavTrack stored) apply,
    required Iterable<String> changedCardIds,
  }) => writeRecordSitting<NavTrack>(
    table: 'nav_tracks',
    recordId: routeId,
    changedCardIds: changedCardIds,
    read: () => _routes.getById(routeId, includePoints: false),
    apply: apply,
    write: (stored, merged) async {
      await _routes.writeEditedColumns(
        routeId,
        name: merged.name,
        siteId: merged.siteId,
        equipmentId: merged.equipmentId,
        deviceName: merged.deviceName,
        correction: merged.correction,
      );
      final from = stored.diveId;
      final to = merged.diveId;
      if (from == to) return;
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
