import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// Figures for the Tracks page's summary strip.
///
/// Everything comes from stored scalars and the in-memory dive list; no
/// point blob is decoded.
class TracksSummary {
  const TracksSummary({
    required this.trackCount,
    required this.recordedTime,
    required this.divesCovered,
  });

  final int trackCount;
  final Duration recordedTime;

  /// Dives with a GPS track around their entry or an underwater track
  /// linked to them, each counted once.
  final int divesCovered;
}

/// Summarises [items] (already filtered) against the diver's [dives].
///
/// The two kinds answer "which dive" differently: GPS coverage is by time
/// window, with the matcher's own tolerance; underwater coverage is by the
/// stored link. A link to a dive outside [dives] (another diver's, or one
/// not loaded) is not counted.
TracksSummary summarizeTracks(List<TrackListItem> items, List<Dive> dives) {
  final recorded = items.fold<Duration>(
    Duration.zero,
    (total, item) => total + (item.recordedTime ?? Duration.zero),
  );
  final gpsTracks = [
    for (final item in items)
      if (item is GpsTrackItem) item.track,
  ];
  final diveIds = {for (final dive in dives) dive.id};
  final covered = <String>{
    for (final dive in dives)
      // millisecondsSinceEpoch is absolute regardless of the utc flag, so it
      // compares directly against the wall-clock-as-UTC track window.
      if (GpsTrackMatcher.trackCovering(
            gpsTracks,
            dive.effectiveEntryTime.millisecondsSinceEpoch,
          ) !=
          null)
        dive.id,
    for (final item in items)
      if (item is UnderwaterTrackItem && diveIds.contains(item.track.diveId))
        item.track.diveId!,
  };
  return TracksSummary(
    trackCount: items.length,
    recordedTime: recorded,
    divesCovered: covered.length,
  );
}
