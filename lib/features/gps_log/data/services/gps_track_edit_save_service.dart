import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';

/// Writes a GPS track page's editing sitting (issue #4527, phase 3): its
/// name and trim, in one transaction and one History entry labelled with
/// the cards it changed.
class GpsTrackEditSaveService {
  GpsTrackEditSaveService(this._tracks);

  final GpsTrackRepository _tracks;

  /// Saves [apply] onto track [trackId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept. Writes only the
  /// name and the trim; the recorded points are never read or written.
  /// Returns the track before and after, or null when nothing changed.
  /// Throws [StateError] when the track no longer exists.
  Future<({GpsTrack before, GpsTrack after})?> save({
    required String trackId,
    required GpsTrack Function(GpsTrack stored) apply,
    required Iterable<String> changedCardIds,
  }) => writeRecordSitting<GpsTrack>(
    table: 'gps_tracks',
    recordId: trackId,
    changedCardIds: changedCardIds,
    read: () => _tracks.getTrack(trackId, includePoints: false),
    // GpsTrack has no value equality, so the stored track itself stands for
    // "nothing to write": the writer compares with ==.
    apply: (stored) {
      final merged = apply(stored);
      return _sameEdit(merged, stored) ? stored : merged;
    },
    write: (_, merged) => _tracks.writeEditedColumns(
      trackId,
      name: merged.name,
      trimStartTime: merged.trimStartTime,
      trimEndTime: merged.trimEndTime,
    ),
  );
}

/// Whether [a] and [b] hold the same name and trim: the only values a
/// sitting writes.
bool _sameEdit(GpsTrack a, GpsTrack b) =>
    a.name == b.name &&
    a.trimStartTime == b.trimStartTime &&
    a.trimEndTime == b.trimEndTime;

final gpsTrackEditSaveServiceProvider = Provider<GpsTrackEditSaveService>(
  (ref) => GpsTrackEditSaveService(ref.watch(gpsTrackRepositoryProvider)),
);
