import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/gpx/gpx_export_service.dart';
import 'package:submersion/core/services/export/kml/kml_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';

/// Argument bundle for the isolate. compute() takes exactly one argument.
class _SimplifyRequest {
  final List<GpsTrackPoint> points;
  final double toleranceMeters;

  const _SimplifyRequest(this.points, this.toleranceMeters);
}

/// Top-level so it can run in an isolate.
List<GpsTrackPoint> _simplifyInIsolate(_SimplifyRequest request) =>
    simplifyTrack(request.points, request.toleranceMeters);

final trackGeometryCacheRepositoryProvider =
    Provider<TrackGeometryCacheRepository>(
      (ref) => TrackGeometryCacheRepository(),
    );

/// A single hydrated track, points blob decoded. This is the expensive step
/// and it happens once per track.
final gpsTrackDetailProvider = FutureProvider.family<GpsTrack?, String>((
  ref,
  trackId,
) async {
  final repository = ref.watch(gpsTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTracksChanges());
  return repository.getTrack(trackId, includePoints: true);
});

/// Simplified geometry at a given level of detail, cached across launches.
final gpsTrackGeometryProvider =
    FutureProvider.family<List<GpsTrackPoint>, (String, TrackLod)>((
      ref,
      key,
    ) async {
      final (trackId, lod) = key;
      final cache = ref.watch(trackGeometryCacheRepositoryProvider);
      // A trim or split calls cache.invalidate, dropping every LOD for the
      // track; without this the map kept drawing the pre-trim polyline.
      ref.invalidateSelfWhen(cache.watchGeometryChanges());

      final cached = await cache.read(trackId, lod);
      if (cached != null) return cached;

      final track = await ref.watch(gpsTrackDetailProvider(trackId).future);
      if (track == null) return const [];

      // Read through effectivePoints so trim bounds are honoured before
      // simplification rather than after.
      final simplified = await compute(
        _simplifyInIsolate,
        _SimplifyRequest(track.effectivePoints, lod.toleranceMeters),
      );
      await cache.write(trackId, lod, simplified);
      return simplified;
    });

/// Wall-clock-as-UTC epoch milliseconds for a dive's entry.
///
/// millisecondsSinceEpoch is absolute regardless of the DateTime's utc flag,
/// so this compares directly against gps_tracks.startTime, which stores the
/// same wall-clock-as-UTC value.
int _entryMillis(Dive dive) => dive.effectiveEntryTime.millisecondsSinceEpoch;

/// Dives whose entry falls inside [trackId]'s recording window.
///
/// Uses [GpsTrackMatcher.trackCovering] rather than a bare range test so the
/// markers show exactly the dives this track could have stamped - same
/// 30-minute tolerance the match sweep applies.
final divesOnTrackProvider = FutureProvider.family<List<Dive>, String>((
  ref,
  trackId,
) async {
  final track = await ref.watch(gpsTrackDetailProvider(trackId).future);
  // An in-progress track has no closed window to test dives against.
  if (track == null || track.endTime == null) return const [];

  final dives = await ref.watch(divesProvider.future);
  return [
    for (final dive in dives)
      if (GpsTrackMatcher.trackCovering([track], _entryMillis(dive)) != null)
        dive,
  ];
});

/// The track, if any, whose window covers [diveId].
final trackForDiveProvider = FutureProvider.family<GpsTrack?, String>((
  ref,
  diveId,
) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  if (dive == null) return null;

  final repository = ref.watch(gpsTrackRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTracksChanges());

  // Lean read first - never decode every blob just to find the match.
  final tracks = await repository.getCompletedTracks(includePoints: false);
  final match = GpsTrackMatcher.trackCovering(tracks, _entryMillis(dive));
  if (match == null) return null;
  return ref.watch(gpsTrackDetailProvider(match.id).future);
});

/// Optional date bound on the overview map.
///
/// Null means unbounded. Track start times are wall-clock-as-UTC, so the
/// range's DateTime values compare against them directly with no conversion.
final trackDateFilterProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Most tracks the overview map will draw at once.
///
/// The date filter defaults to unbounded, so without a cap a library of 200
/// boat days would, on a cold cache, hydrate 200 full point blobs and spawn
/// 200 concurrent compute() isolates in a single frame - each deep-copying
/// its points across the port both ways. The local cache is never backed up,
/// so a restored or reinstalled device starts cold. Newest first, because
/// that is what a diver is looking for.
const int kOverviewTrackLimit = 40;

/// Completed tracks narrowed by [trackDateFilterProvider].
///
/// "Every track ever" is the one query in this feature that grows without
/// bound, so the overview map reads through this rather than gpsTracksProvider.
final filteredTracksProvider = FutureProvider<List<GpsTrack>>((ref) async {
  final tracks = await ref.watch(gpsTracksProvider.future);
  final range = ref.watch(trackDateFilterProvider);
  if (range == null) return tracks;

  final from = range.start.millisecondsSinceEpoch;
  // Inclusive of the end date's full day.
  final to = range.end
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1))
      .millisecondsSinceEpoch;

  return [
    for (final track in tracks)
      if (track.startTime >= from && track.startTime <= to) track,
  ];
});

/// What the overview map actually draws: [filteredTracksProvider] capped at
/// [kOverviewTrackLimit].
///
/// gpsTracksProvider already returns newest first, so the cap keeps the most
/// recent boat days.
final overviewTracksProvider = FutureProvider<List<GpsTrack>>((ref) async {
  final tracks = await ref.watch(filteredTracksProvider.future);
  return tracks.length <= kOverviewTrackLimit
      ? tracks
      : tracks.sublist(0, kOverviewTrackLimit);
});

/// True when [overviewTracksProvider] dropped tracks the filter allowed.
final overviewTracksTruncatedProvider = Provider<bool>((ref) {
  final all = ref.watch(filteredTracksProvider).value?.length ?? 0;
  return all > kOverviewTrackLimit;
});

/// Drops every cached and in-memory derivative of [id].
///
/// gpsTrackGeometryProvider returns early on a persisted cache hit, BEFORE it
/// watches gpsTrackDetailProvider, so on a warm cache there is no dependency
/// edge for a detail invalidation to travel along. Each LOD therefore has to
/// be invalidated by name, or the map keeps drawing the pre-trim polyline
/// while the stats header updates - the trim looks like it silently failed.
Future<void> _evictTrack(Ref ref, String id) async {
  await ref.read(trackGeometryCacheRepositoryProvider).invalidate(id);
  for (final lod in TrackLod.values) {
    ref.invalidate(gpsTrackGeometryProvider((id, lod)));
  }
  ref.invalidate(gpsTrackDetailProvider(id));
}

/// Trims a track and drops its cached geometry.
///
/// Cache invalidation lives here rather than in the repository so the data
/// layer stays unaware of the presentation cache.
final trimTrackProvider = Provider(
  (ref) => (String id, {int? startMs, int? endMs}) async {
    await ref
        .read(gpsTrackRepositoryProvider)
        .setTrimBounds(id, startMs: startMs, endMs: endMs);
    await _evictTrack(ref, id);
  },
);

/// Splits a track and drops the parent's cached geometry.
final splitTrackProvider = Provider(
  (ref) => (String id, int atWallClockMs) async {
    final result = await ref
        .read(gpsTrackRepositoryProvider)
        .splitTrack(id, atWallClockMs);
    await _evictTrack(ref, id);
    // A dive detail page still linking to the deleted parent would otherwise
    // navigate to a track that no longer exists.
    ref.invalidate(trackForDiveProvider);
    ref.invalidate(gpsTracksProvider);
    return result;
  },
);

/// Deletes a track and drops its cached geometry.
///
/// Without this the local cache keeps up to three orphan blobs per deleted
/// track: it has no TTL, no foreign key, no GC, and nothing else in the app
/// ever clears that database.
final deleteTrackProvider = Provider(
  (ref) => (String id) async {
    await ref.read(gpsTrackRepositoryProvider).deleteTrack(id);
    await _evictTrack(ref, id);
    ref.invalidate(trackForDiveProvider);
    ref.invalidate(gpsTracksProvider);
  },
);

final trackImportServiceProvider = Provider<TrackImportService>(
  (ref) => TrackImportService(),
);

final gpxExportServiceProvider = Provider<GpxExportService>(
  (ref) => GpxExportService(),
);

final kmlExportServiceProvider = Provider<KmlExportService>(
  (ref) => KmlExportService(),
);

/// Active colorization mode on the track detail map.
///
/// Held outside the geometry providers on purpose: changing it must re-run
/// bucketizeTrack only, never the decode or the simplify.
final trackColorModeProvider = StateProvider<TrackColorMode>(
  (ref) => TrackColorMode.uniform,
);
