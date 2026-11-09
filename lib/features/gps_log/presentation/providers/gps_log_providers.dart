import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/dive_mark_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

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

/// "Entered water" and "Surfaced" (issue #637), at the running recording's
/// position. One instance, so "Surfaced" remembers who entered the water.
// no-tick: builds the DiveMarkService SERVICE, not a query result. Its track
// read runs fresh at each tap.
final diveMarkServiceProvider = Provider<DiveMarkService>((ref) {
  final recorder = ref.watch(gpsTrackRecorderProvider);
  final tracks = ref.watch(gpsTrackRepositoryProvider);
  return DiveMarkService(
    drafts: ref.watch(diveDraftRepositoryProvider),
    currentDiverId: () => ref.read(currentDiverIdProvider),
    recordedPoints: () async {
      final trackId = recorder.state.trackId;
      return trackId == null ? const [] : tracks.getBufferPoints(trackId);
    },
  );
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
