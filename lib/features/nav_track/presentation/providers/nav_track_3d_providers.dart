import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_scene_geometry_service.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_z_axis_input.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Scene data for the track 3D preview. Null when the route is missing or
/// has no usable profile (fewer than two active-range samples), which the
/// page shows as its no-profile message rather than a spinner. Reactivity
/// comes from `navTrackByIdProvider`, already invalidated on
/// `NavTrackRepository.watchRouteChanges`.
final navTrack3dSceneDataProvider =
    FutureProvider.family<NavTrack3dSceneData?, String>((ref, trackId) async {
      final route = await ref.watch(navTrackByIdProvider(trackId).future);
      if (route == null) return null;
      final data = NavTrack3dSceneData.fromRoute(route);
      return data.hasProfile ? data : null;
    });

typedef NavTrack3dGeometryKey = ({
  String trackId,
  TrackSceneMetric colorMetric,
  TrackSceneMetric? zMetric,
});
typedef NavTrack3dZAxisKey = ({String trackId, TrackSceneMetric? zMetric});

/// The Z axis for (track, metric) in the diver's display units, or null
/// for None, for an unavailable metric, or while scene data is still
/// loading. Watches settings so a unit change re-fits the axis, mirroring
/// `dive3dZAxisProvider`.
final navTrack3dZAxisProvider =
    Provider.family<TrackZAxisInput?, NavTrack3dZAxisKey>((ref, key) {
      final zMetric = key.zMetric;
      final data = ref.watch(navTrack3dSceneDataProvider(key.trackId)).value;
      if (zMetric == null || data == null) return null;
      return buildTrackZAxisInput(
        data,
        zMetric,
        UnitFormatter(ref.watch(settingsProvider)),
      );
    });

/// Profiles below this sample count build geometry synchronously; the
/// isolate hop only pays for itself on large recordings (the sample
/// Seacraft ENC log used during review ran to 6600+ raw rows).
const int _computeThreshold = 2000;

Scene3d _buildGeometry(
  (NavTrack3dSceneData, TrackSceneMetric, TrackZAxisInput?) input,
) => const NavTrackSceneGeometryService().build(
  input.$1,
  input.$2,
  zAxis: input.$3,
);

/// Scene per (track, color metric, Z metric). Family caching makes
/// switching back instant; `compute()` keeps large builds off the UI
/// thread, same threshold and reasoning as `dive3dGeometryProvider`.
final navTrack3dGeometryProvider =
    FutureProvider.family<Scene3d?, NavTrack3dGeometryKey>((ref, key) async {
      final data = await ref.watch(
        navTrack3dSceneDataProvider(key.trackId).future,
      );
      if (data == null) return null;
      final zAxis = ref.watch(
        navTrack3dZAxisProvider((trackId: key.trackId, zMetric: key.zMetric)),
      );
      if (data.times.length < _computeThreshold) {
        return _buildGeometry((data, key.colorMetric, zAxis));
      }
      return compute(_buildGeometry, (data, key.colorMetric, zAxis));
    });
