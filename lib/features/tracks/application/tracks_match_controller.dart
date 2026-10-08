import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';

const _log = LoggerService('TracksMatchController');

/// What one press of the Tracks page's Match action did.
class TracksMatchOutcome {
  const TracksMatchOutcome({
    required this.positionedDiveIds,
    required this.failed,
  });

  /// Dives the GPS sweep gave coordinates to; the site review takes these.
  final List<String> positionedDiveIds;

  /// The sweep threw; nothing was positioned.
  final bool failed;
}

/// Runs the Tracks page's Match action: the GPS sweep, which positions
/// GPS-less dives from the recorded tracks.
///
/// Underwater tracks take no part: a sweep only ever suggests a dive for
/// them, and linking always goes through the diver's own choice on the
/// track's detail page (#2394). The list's pending-choice hint counts those
/// waiting tracks on its own.
class TracksMatchController {
  const TracksMatchController({required GpsTrackMatchService gps}) : _gps = gps;

  final GpsTrackMatchService _gps;

  Future<TracksMatchOutcome> matchAll() async {
    try {
      return TracksMatchOutcome(
        positionedDiveIds: await _gps.sweep(),
        failed: false,
      );
    } catch (e, stackTrace) {
      // Matching is best-effort everywhere else; a button press must not
      // surface an uncaught error either.
      _log.error('GPS match sweep failed', error: e, stackTrace: stackTrace);
      return const TracksMatchOutcome(positionedDiveIds: [], failed: true);
    }
  }
}

final tracksMatchControllerProvider = Provider<TracksMatchController>(
  (ref) => TracksMatchController(gps: ref.watch(gpsTrackMatchServiceProvider)),
);
