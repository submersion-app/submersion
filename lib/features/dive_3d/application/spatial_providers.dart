import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

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

/// The renderable per-dive seascape plus terrain provenance (null source
/// means the synthesized fallback seafloor).
class SpatialSceneResult {
  final Scene3d scene;
  final String? bathymetrySourceId;
  final double? bathymetryResolutionMeters;

  /// The scene-frame numbers for the distance/depth axes; null only for
  /// results constructed without them (older tests, degenerate scenes).
  final SeascapeAxisInputs? axisInputs;

  /// The terrain's source grid when the seafloor is real bathymetry; null
  /// for the synthesized fallback, whose invented surface offers no honest
  /// per-point readout (so hover inspection is disabled there).
  final BathymetryGrid? grid;

  const SpatialSceneResult({
    required this.scene,
    this.bathymetrySourceId,
    this.bathymetryResolutionMeters,
    this.axisInputs,
    this.grid,
  });
}

typedef _SpatialBuildInput = ({
  ReckonedPath path,
  double? siteMaxDepth,
  BathymetryGrid? grid,
  GeoPoint? gridCenter,
  ({double east, double north}) pathAnchor,
});

final spatialGeometryProvider =
    FutureProvider.family<SpatialSceneResult?, String>((ref, diveId) async {
      final path = await ref.watch(spatialReckonedPathProvider(diveId).future);
      if (path == null || path.points.length < 2) return null;
      final dive = await ref.watch(diveProvider(diveId).future);
      final siteMaxDepth = dive?.site?.maxDepth;

      // Real terrain when any anchor coordinate exists: prefer the site
      // pin, else the dive's own entry fix. Null grid (no coordinates,
      // offline-and-uncached, definitive empty) falls back to synthesized.
      final center = dive?.site?.location ?? dive?.entryLocation;
      BathymetryGrid? grid;
      if (center != null) {
        grid = await ref.watch(
          bathymetryGridProvider(BathymetryRepository.quantize(center)).future,
        );
      }
      final entry = dive?.entryLocation;
      final anchor = (grid != null && center != null && entry != null)
          ? enuOffsetMeters(center, entry)
          : (east: 0.0, north: 0.0);

      final input = (
        path: path,
        siteMaxDepth: siteMaxDepth,
        grid: grid,
        gridCenter: grid == null ? null : center,
        pathAnchor: anchor,
      );
      final cells = grid == null ? 0 : grid.rows * grid.cols;
      final built = (path.points.length < 4000 && cells < 4000)
          ? _buildSpatial(input)
          : await compute(_buildSpatial, input);
      return SpatialSceneResult(
        scene: built.scene,
        bathymetrySourceId: grid?.sourceId,
        bathymetryResolutionMeters: grid?.resolutionMeters,
        axisInputs: built.frame,
        grid: grid,
      );
    });

({Scene3d scene, SeascapeAxisInputs frame}) _buildSpatial(
  _SpatialBuildInput input,
) => const SpatialGeometryService().buildWithFrame(
  input.path,
  siteMaxDepth: input.siteMaxDepth,
  grid: input.grid,
  gridCenter: input.gridCenter,
  pathAnchor: input.pathAnchor,
);
