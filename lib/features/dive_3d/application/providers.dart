import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';

/// Assembles scene data from the primary/active source. Returns null when
/// the dive has no usable profile (manual logs) so the UI can hide all 3D
/// entry points. Reactivity comes from the upstream providers, which all
/// self-invalidate on watchDiveDetailChanges. A null active source id
/// means "the primary source"; sourceProfilesProvider orders primary
/// first.
final dive3dSceneDataProvider = FutureProvider.family<Dive3dSceneData?, String>(
  (ref, diveId) async {
    final sourceProfiles = await ref.watch(
      sourceProfilesProvider(diveId).future,
    );
    final activeSourceId = ref.watch(activeDiveSourceProvider(diveId));
    final profile =
        (activeSourceId != null
                ? sourceProfiles[activeSourceId] ??
                      sourceProfiles.values.firstOrNull
                : sourceProfiles.values.firstOrNull)
            ?.points;
    if (profile == null || profile.length < 2) return null;

    final tankPressures = await ref.watch(tankPressuresProvider(diveId).future);
    final gasSwitches = await ref.watch(gasSwitchesProvider(diveId).future);
    final events = await ref.watch(diveComputerEventsProvider(diveId).future);
    final photos = await ref.watch(mediaForDiveProvider(diveId).future);

    return Dive3dSceneData.fromDomain(
      diveId: diveId,
      points: profile,
      tankPressures: tankPressures,
      gasSwitches: gasSwitches,
      events: events,
      photos: photos,
    );
  },
);

typedef Dive3dGeometryKey = ({String diveId, SceneMetric metric});

Scene3d _buildGeometry((Dive3dSceneData, SceneMetric, double) input) =>
    const SceneGeometryService().build(
      input.$1,
      input.$2,
      gridStepMeters: input.$3,
    );

/// Profiles below this sample count build geometry synchronously; the
/// isolate hop only pays for itself on large tech-dive profiles.
const int _computeThreshold = 2000;

/// Scene per (dive, metric). Family caching makes metric switch-back
/// instant; compute() keeps large builds off the UI thread.
final dive3dGeometryProvider =
    FutureProvider.family<Scene3d?, Dive3dGeometryKey>((ref, key) async {
      final data = await ref.watch(dive3dSceneDataProvider(key.diveId).future);
      if (data == null) return null;
      // Grid lines land on round numbers in the diver's display unit:
      // 10 m steps for metric, 25 ft (7.62 m) for imperial.
      final depthUnit = ref.watch(settingsProvider).depthUnit;
      final gridStep = depthUnit == DepthUnit.feet ? 7.62 : 10.0;
      if (data.times.length < _computeThreshold) {
        return _buildGeometry((data, key.metric, gridStep));
      }
      return compute(_buildGeometry, (data, key.metric, gridStep));
    });
