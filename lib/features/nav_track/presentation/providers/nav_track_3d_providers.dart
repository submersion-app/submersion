import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_scene_geometry_service.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

/// Scene data for the track 3D preview. Null when the route has no
/// usable profile (fewer than two active-range samples), mirroring
/// `dive3dSceneDataProvider`'s own null-hides-the-entry-point contract.
/// Reactivity comes from `navTrackByIdProvider`, already invalidated on
/// `NavTrackRepository.watchRouteChanges`.
final navTrack3dSceneDataProvider =
    FutureProvider.family<NavTrack3dSceneData?, String>((ref, trackId) async {
      final route = await ref.watch(navTrackByIdProvider(trackId).future);
      if (route == null) return null;
      final data = NavTrack3dSceneData.fromRoute(route);
      return data.hasProfile ? data : null;
    });

/// Profiles below this sample count build geometry synchronously; the
/// isolate hop only pays for itself on large recordings (the sample
/// Seacraft ENC log used during review ran to 6600+ raw rows).
const int _computeThreshold = 2000;

Scene3d _buildGeometry((NavTrack3dSceneData, TrackSceneMetric) input) =>
    const NavTrackSceneGeometryService().build(input.$1, input.$2);

/// Scene per (track, color metric). Family caching makes switching the
/// metric picker back instant; `compute()` keeps large builds off the UI
/// thread, same threshold and reasoning as `dive3dGeometryProvider`.
final navTrack3dGeometryProvider =
    FutureProvider.family<Scene3d?, (String, TrackSceneMetric)>((
      ref,
      key,
    ) async {
      final data = await ref.watch(navTrack3dSceneDataProvider(key.$1).future);
      if (data == null) return null;
      if (data.times.length < _computeThreshold) {
        return _buildGeometry((data, key.$2));
      }
      return compute(_buildGeometry, (data, key.$2));
    });
