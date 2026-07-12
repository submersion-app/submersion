import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// The reconstructed swim path for a dive (dead reckoning), or null when the
/// dive has no usable profile.
final spatialReckonedPathProvider =
    FutureProvider.family<ReckonedPath?, String>((ref, diveId) async {
      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null) return null;
      final sources = await ref.watch(sourceProfilesProvider(diveId).future);
      // Respect the source the diver has selected on the detail page; fall
      // back to the primary source when none is active.
      final activeSourceId = ref.watch(activeDiveSourceProvider(diveId));
      final selected = activeSourceId != null
          ? sources[activeSourceId] ?? sources.values.firstOrNull
          : sources.values.firstOrNull;
      final points = selected?.points ?? const [];
      if (points.length < 2) return null;

      final sorted = [...points]..sort((a, b) => a.timestamp - b.timestamp);
      final times = [for (final p in sorted) p.timestamp.toDouble()];
      final depths = [for (final p in sorted) p.depth];
      final headings = [for (final p in sorted) p.heading];

      ({double east, double north})? exitOffset;
      final entry = dive.entryLocation, exit = dive.exitLocation;
      if (entry != null && exit != null) {
        final d = distanceMeters(entry, exit);
        final brg = initialBearingDegrees(entry, exit) * math.pi / 180.0;
        exitOffset = (east: d * math.sin(brg), north: d * math.cos(brg));
      }

      return const DeadReckoningService().reckon(
        times: times,
        depths: depths,
        headings: headings,
        exitOffset: exitOffset,
      );
    });

/// The renderable spatial seascape scene for a dive.
final spatialGeometryProvider = FutureProvider.family<Scene3d?, String>((
  ref,
  diveId,
) async {
  final path = await ref.watch(spatialReckonedPathProvider(diveId).future);
  if (path == null || path.points.length < 2) return null;
  final dive = await ref.watch(diveProvider(diveId).future);
  final siteMaxDepth = dive?.site?.maxDepth;
  final input = (path, siteMaxDepth);
  if (path.points.length < 4000) {
    return const SpatialGeometryService().build(
      input.$1,
      siteMaxDepth: input.$2,
    );
  }
  return compute(_spatialIsolate, input);
});

Scene3d _spatialIsolate((ReckonedPath, double?) input) =>
    const SpatialGeometryService().build(input.$1, siteMaxDepth: input.$2);
