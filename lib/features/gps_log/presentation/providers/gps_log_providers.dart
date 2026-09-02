import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';

final gpsTrackRepositoryProvider = Provider<GpsTrackRepository>(
  (ref) => GpsTrackRepository(),
);

final gpsTrackMatchServiceProvider = Provider<GpsTrackMatchService>(
  (ref) => GpsTrackMatchService(
    trackRepository: ref.watch(gpsTrackRepositoryProvider),
    diveRepository: ref.watch(diveRepositoryProvider),
  ),
);

final gpsTrackRecorderProvider = Provider<GpsTrackRecorder>((ref) {
  final recorder = GpsTrackRecorder(
    repository: ref.watch(gpsTrackRepositoryProvider),
    // A freshly finalized track may cover already-imported GPS-less dives.
    onTrackFinalized: (_) async {
      await ref.read(gpsTrackMatchServiceProvider).sweep();
    },
  );
  ref.onDispose(recorder.stop);
  return recorder;
});

final gpsRecorderStateProvider = StreamProvider<GpsRecorderState>(
  (ref) => ref.watch(gpsTrackRecorderProvider).states,
);

/// Completed tracks for the logger page list, newest first.
final gpsTracksProvider = FutureProvider<List<GpsTrack>>((ref) async {
  final repository = ref.watch(gpsTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTracksChanges());
  return repository.getCompletedTracks();
});

/// Figures for the logger page's summary strip.
///
/// Everything here comes from stored scalars and the in-memory dive list:
/// no track blob is decoded, so it stays cheap for a library of hundreds of
/// boat days. Distance is deliberately absent - it is not stored, and a
/// figure derived from simplified geometry would disagree with the detail
/// page.
class GpsLogSummary {
  final int trackCount;

  /// Total recorded time across completed tracks, each honouring its trim.
  final Duration recordedTime;

  /// Dives whose entry falls inside some track's window, by the same
  /// tolerance the match sweep and the detail markers apply.
  final int divesCovered;

  const GpsLogSummary({
    required this.trackCount,
    required this.recordedTime,
    required this.divesCovered,
  });
}

final gpsLogSummaryProvider = FutureProvider<GpsLogSummary>((ref) async {
  final tracks = await ref.watch(gpsTracksProvider.future);
  final dives = await ref.watch(divesProvider.future);

  var recordedMs = 0;
  for (final track in tracks) {
    final end = track.effectiveEndTime;
    if (end == null) continue;
    recordedMs += end - track.effectiveStartTime;
  }

  var covered = 0;
  for (final dive in dives) {
    // millisecondsSinceEpoch is absolute regardless of the utc flag, so it
    // compares directly against the wall-clock-as-UTC track window.
    final entryMs = dive.effectiveEntryTime.millisecondsSinceEpoch;
    if (GpsTrackMatcher.trackCovering(tracks, entryMs) != null) covered += 1;
  }

  return GpsLogSummary(
    trackCount: tracks.length,
    recordedTime: Duration(milliseconds: recordedMs),
    divesCovered: covered,
  );
});
