import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/nav_track_match_suggestion.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';

/// Reports unlinked routes and, where exactly one dive overlaps, which one
/// to suggest. It never links anything itself (#2394: a route used to be
/// linked silently the instant exactly one dive overlapped it, with no way
/// to decline before the fact). The suggestion rule itself is
/// `NavTrackMatcher.soleCandidateFor`, shared with the route detail page's
/// "Choose dive" so the two can never suggest different dives. This mirrors
/// `GpsTrackMatchService`'s own role for surface tracks.
class NavTrackMatchService {
  final NavTrackRepository _routeRepository;
  final DiveRepository _diveRepository;
  final Future<String?> Function() _currentDiverId;

  /// [currentDiverId] resolves the active diver: a sweep then considers
  /// only that diver's routes and the ownerless ones, and suggests only
  /// that diver's dives. Omitted (or resolving to null), every route and
  /// dive is considered.
  NavTrackMatchService({
    required NavTrackRepository routeRepository,
    required DiveRepository diveRepository,
    Future<String?> Function()? currentDiverId,
  }) : _routeRepository = routeRepository,
       _diveRepository = diveRepository,
       _currentDiverId = currentDiverId ?? _noDiver;

  static Future<String?> _noDiver() async => null;

  /// One entry per unlinked route in scope, confirming or picking a
  /// different dive is entirely up to the diver (the route detail page's
  /// "Choose dive", or the routes list's own hint). `suggestedDiveId` is the
  /// sole dive whose time window overlaps the route; it is null when none
  /// overlap (genuinely unmatched) or more than one does (ambiguous) --
  /// both still belong in the report, since either way the diver is the one
  /// who decides. A route already linked -- by hand, or by confirming an
  /// earlier suggestion -- is never reconsidered:
  /// `NavTrackRepository.getUnlinked` excludes it, so a sweep can never
  /// touch a route the diver has already placed.
  ///
  /// [limitToRouteIds] scopes the sweep to specific routes (import-time:
  /// just the route that was imported); [limitToDiveIds] scopes it to
  /// specific dives (a dive-computer download: just the dives it brought
  /// in). Neither is required for a full sweep.
  Future<List<NavTrackMatchSuggestion>> sweep({
    List<String>? limitToRouteIds,
    List<String>? limitToDiveIds,
  }) async {
    final diverId = await _currentDiverId();
    var routes = await _routeRepository.getUnlinked(diverId: diverId);
    if (limitToRouteIds != null) {
      final ids = limitToRouteIds.toSet();
      routes = [
        for (final route in routes)
          if (ids.contains(route.id)) route,
      ];
    }
    if (routes.isEmpty) return const [];

    final dives = limitToDiveIds != null
        ? [
            for (final dive in await _diveRepository.getDivesByIds(
              limitToDiveIds,
            ))
              if (diverId == null || dive.diverId == diverId) dive,
          ]
        : await _diveRepository.getAllDives(diverId: diverId);

    return [
      for (final route in routes)
        (
          routeId: route.id,
          suggestedDiveId: NavTrackMatcher.soleCandidateFor(
            routeStartSeconds: route.startTime ~/ 1000,
            routeEndSeconds: route.endTime ~/ 1000,
            dives: dives,
          )?.id,
        ),
    ];
  }
}
