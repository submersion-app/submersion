import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_service_providers.dart';

const _log = LoggerService('TracksMatchController');

/// What one press of the Tracks page's Match action did.
class TracksMatchOutcome {
  const TracksMatchOutcome({
    required this.positionedDiveIds,
    required this.linkedUnderwaterIds,
    required this.anyFailed,
  });

  /// Dives the GPS sweep gave coordinates to; the site review takes these.
  final List<String> positionedDiveIds;

  /// Underwater tracks the sweep linked to a dive.
  final List<String> linkedUnderwaterIds;

  /// Either sweep threw. The other one still ran.
  final bool anyFailed;

  bool get matchedAnything =>
      positionedDiveIds.isNotEmpty || linkedUnderwaterIds.isNotEmpty;
}

/// Runs both dive-matching sweeps for the Tracks page.
///
/// Sequential, not parallel: both write dive links, and the GPS sweep also
/// writes dive coordinates. Each sweep is guarded on its own so a failure in
/// one never skips the other.
class TracksMatchController {
  const TracksMatchController({
    required GpsTrackMatchService gps,
    required NavTrackMatchService underwater,
  }) : _gps = gps,
       _underwater = underwater;

  final GpsTrackMatchService _gps;
  final NavTrackMatchService _underwater;

  Future<TracksMatchOutcome> matchAll() async {
    var anyFailed = false;

    var positioned = const <String>[];
    try {
      positioned = await _gps.sweep();
    } catch (e, stackTrace) {
      _log.error('GPS match sweep failed', error: e, stackTrace: stackTrace);
      anyFailed = true;
    }

    var linked = const <String>[];
    try {
      linked = (await _underwater.sweep()).linked;
    } catch (e, stackTrace) {
      _log.error(
        'Underwater match sweep failed',
        error: e,
        stackTrace: stackTrace,
      );
      anyFailed = true;
    }

    return TracksMatchOutcome(
      positionedDiveIds: positioned,
      linkedUnderwaterIds: linked,
      anyFailed: anyFailed,
    );
  }
}

final tracksMatchControllerProvider = Provider<TracksMatchController>(
  (ref) => TracksMatchController(
    gps: ref.watch(gpsTrackMatchServiceProvider),
    underwater: ref.watch(navTrackMatchServiceProvider),
  ),
);
