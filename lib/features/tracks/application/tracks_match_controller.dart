import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

const _log = LoggerService('TracksMatchController');

/// What one press of the Tracks page's Match action found.
class TracksMatchOutcome {
  const TracksMatchOutcome({
    required this.positionedDiveIds,
    required this.failed,
    this.linkProposals = const [],
    this.linkedTrackCount = 0,
    this.linkConfirmed = false,
  });

  /// Dives the GPS sweep gave coordinates to; the site review takes these.
  final List<String> positionedDiveIds;

  /// Part of the action threw: the GPS sweep, reading the underwater
  /// tracks, or linking one.
  final bool failed;

  /// Unlinked underwater tracks, each with the one dive its recording
  /// overlaps, for the diver to confirm (#4851).
  final List<NavTrackLinkProposal> linkProposals;

  /// How many of [linkProposals] the diver's confirmation linked.
  final int linkedTrackCount;

  /// The diver chose Link: [linkedTrackCount] is then worth reporting even
  /// at 0, when every track was linked or its dive deleted meanwhile.
  final bool linkConfirmed;

  /// This outcome once the diver's confirmation has linked [linked] tracks;
  /// [failed] when a link threw.
  TracksMatchOutcome afterLinking({
    required int linked,
    required bool failed,
  }) => TracksMatchOutcome(
    positionedDiveIds: positionedDiveIds,
    failed: this.failed || failed,
    linkProposals: linkProposals,
    linkedTrackCount: linked,
    linkConfirmed: true,
  );
}

/// Runs the Tracks page's Match action: the GPS sweep, which positions
/// GPS-less dives from the recorded tracks, and the underwater tracks'
/// matches by time.
///
/// An underwater track is never linked by the sweep itself (#2394): Match
/// proposes each unlinked track whose recording overlaps exactly one dive,
/// and [linkProposals] links them once the diver confirms (#4851). A track
/// with no overlapping dive, or several, still waits for the diver's choice
/// on its own page.
class TracksMatchController {
  const TracksMatchController({
    required GpsTrackMatchService gps,
    required NavTrackRepository routes,
    required Future<List<NavTrack>> Function() unlinkedRoutes,
    required Future<List<Dive>> Function() dives,
  }) : _gps = gps,
       _routes = routes,
       _unlinkedRoutes = unlinkedRoutes,
       _dives = dives;

  final GpsTrackMatchService _gps;
  final NavTrackRepository _routes;
  final Future<List<NavTrack>> Function() _unlinkedRoutes;
  final Future<List<Dive>> Function() _dives;

  Future<TracksMatchOutcome> matchAll() async {
    // Matching is best-effort everywhere else; a button press must not
    // surface an uncaught error either. Each half runs whatever the other
    // did.
    var failed = false;
    var positioned = const <String>[];
    try {
      positioned = await _gps.sweep();
    } catch (e, stackTrace) {
      failed = true;
      _log.error('GPS match sweep failed', error: e, stackTrace: stackTrace);
    }
    var proposals = const <NavTrackLinkProposal>[];
    try {
      final routes = await _unlinkedRoutes();
      if (routes.isNotEmpty) {
        proposals = NavTrackMatcher.linkProposals(
          routes: routes,
          dives: await _dives(),
        );
      }
    } catch (e, stackTrace) {
      failed = true;
      _log.error(
        'Underwater track matching failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return TracksMatchOutcome(
      positionedDiveIds: positioned,
      failed: failed,
      linkProposals: proposals,
    );
  }

  /// Links each of [proposals] the diver confirmed, as a match. A dive
  /// deleted meanwhile, or a track linked meanwhile, is passed over; a link
  /// that throws is logged and the rest still go ahead.
  Future<({int linked, bool failed})> linkProposals(
    List<NavTrackLinkProposal> proposals,
  ) async {
    var linked = 0;
    var failed = false;
    for (final (:route, :dive) in proposals) {
      try {
        if (!await _routes.diveExists(dive.id)) continue;
        final didLink = await _routes.link(
          route.id,
          dive.id,
          linkMode: NavTrackLinkMode.auto,
        );
        if (didLink) linked++;
      } catch (e, stackTrace) {
        failed = true;
        _log.error(
          'Linking underwater track ${route.id} to dive ${dive.id} failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return (linked: linked, failed: failed);
  }
}

final tracksMatchControllerProvider = Provider<TracksMatchController>(
  (ref) => TracksMatchController(
    gps: ref.watch(gpsTrackMatchServiceProvider),
    routes: ref.watch(navTrackRepositoryProvider),
    unlinkedRoutes: () => ref.read(unlinkedNavTracksProvider.future),
    dives: () => ref.read(divesProvider.future),
  ),
);
