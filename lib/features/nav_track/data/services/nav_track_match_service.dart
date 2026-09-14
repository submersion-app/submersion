import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';

/// Links unlinked routes to dives by time window. Single choke point for
/// all four triggers (import-time, dive-computer download, post-sync,
/// manual) so matching behaviour cannot diverge between them -- mirrors
/// `GpsTrackMatchService`'s own role for surface tracks.
class NavTrackMatchService {
  final NavTrackRepository _routeRepository;
  final DiveRepository _diveRepository;

  NavTrackMatchService({
    required NavTrackRepository routeRepository,
    required DiveRepository diveRepository,
  }) : _routeRepository = routeRepository,
       _diveRepository = diveRepository;

  /// Links every unlinked route that overlaps exactly one dive's time
  /// window (see `NavTrackMatcher`) with `NavTrackLinkMode.auto`.
  ///
  /// A route with no overlapping dive, or with more than one, is left
  /// alone and reported in `needsChoice`: a zero-match route is genuinely
  /// unmatched rather than ambiguous, but both need the diver's own
  /// choice, so the UI shows them together, "N routes need a manual
  /// choice". A route already linked -- by an earlier sweep or by hand --
  /// is never reconsidered: `NavTrackRepository.getUnlinked` excludes it,
  /// so a manual link can never be overwritten by a later sweep.
  ///
  /// [limitToRouteIds] scopes the sweep to specific routes (import-time:
  /// just the route that was imported); [limitToDiveIds] scopes it to
  /// specific dives (a dive-computer download: just the dives it brought
  /// in). Neither is required for a full sweep (manual, post-sync).
  Future<({List<String> linked, List<String> needsChoice})> sweep({
    List<String>? limitToRouteIds,
    List<String>? limitToDiveIds,
  }) async {
    var routes = await _routeRepository.getUnlinked();
    if (limitToRouteIds != null) {
      final ids = limitToRouteIds.toSet();
      routes = [
        for (final route in routes)
          if (ids.contains(route.id)) route,
      ];
    }
    if (routes.isEmpty) return (linked: <String>[], needsChoice: <String>[]);

    final dives = limitToDiveIds != null
        ? await _diveRepository.getDivesByIds(limitToDiveIds)
        : await _diveRepository.getAllDives();
    if (dives.isEmpty) {
      return (linked: <String>[], needsChoice: <String>[]);
    }

    final linked = <String>[];
    final needsChoice = <String>[];
    for (final route in routes) {
      final candidates = NavTrackMatcher.candidatesFor(
        routeStartSeconds: route.startTime ~/ 1000,
        routeEndSeconds: route.endTime ~/ 1000,
        dives: dives,
      );
      if (candidates.length != 1) {
        needsChoice.add(route.id);
        continue;
      }
      await _routeRepository.link(
        route.id,
        candidates.single.id,
        linkMode: NavTrackLinkMode.auto,
      );
      linked.add(route.id);
    }
    return (linked: linked, needsChoice: needsChoice);
  }
}
