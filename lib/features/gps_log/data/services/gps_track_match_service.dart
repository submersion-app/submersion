import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';

/// Sweeps GPS-less dives against recorded tracks and stamps entry/exit
/// positions. Single choke point for all three triggers (import-time,
/// track-arrival, manual) so matching behavior cannot diverge between them.
class GpsTrackMatchService {
  final GpsTrackRepository _trackRepository;
  final DiveRepository _diveRepository;

  GpsTrackMatchService({
    required GpsTrackRepository trackRepository,
    required DiveRepository diveRepository,
  }) : _trackRepository = trackRepository,
       _diveRepository = diveRepository;

  /// Returns ids of dives that received a GPS position. Only dives with no
  /// entry GPS are candidates; existing positions are never overwritten.
  ///
  /// Deliberately does not recover orphaned tracks: a sweep can fire while a
  /// recording session is active (post-import, post-sync, manual), and
  /// recovery would finalize the live session out from under the recorder.
  /// Unfinalized tracks are simply skipped by [GpsTrackMatcher.trackCovering];
  /// crash recovery runs at page startup when no session is active.
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    final candidates = await _diveRepository.getDivesMissingEntryGps(
      limitToIds: limitToIds,
    );
    if (candidates.isEmpty) return [];

    // Windows first, points only for a track that covers a dive: every
    // wizard import sweeps (issue #3704), and a log of historical dives
    // would otherwise decode every recorded track to match none of them.
    final tracks = await _trackRepository.getCompletedTracks();
    if (tracks.isEmpty) return [];
    final pointsByTrack = <String, List<GpsTrackPoint>>{};

    final stamped = <String>[];
    for (final dive in candidates) {
      final covering = GpsTrackMatcher.trackCovering(tracks, dive.startMs);
      if (covering == null) continue;
      final points = pointsByTrack[covering.id] ??= await _effectivePoints(
        covering.id,
      );
      final entry = GpsTrackMatcher.positionAt(points, dive.startMs ~/ 1000);
      if (entry == null) continue;
      final exit = dive.endMs != null
          ? GpsTrackMatcher.positionAt(points, dive.endMs! ~/ 1000)
          : null;
      await _diveRepository.setDiveGps(
        dive.id,
        entryLatitude: entry.latitude,
        entryLongitude: entry.longitude,
        exitLatitude: exit?.latitude,
        exitLongitude: exit?.longitude,
      );
      stamped.add(dive.id);
    }
    return stamped;
  }

  /// The track's trimmed points, or none if it was deleted mid-sweep.
  Future<List<GpsTrackPoint>> _effectivePoints(String trackId) async =>
      (await _trackRepository.getTrack(trackId))?.effectivePoints ?? const [];
}
