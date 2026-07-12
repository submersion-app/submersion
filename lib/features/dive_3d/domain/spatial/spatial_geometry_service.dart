import 'dart:math' as math;

import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_path_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/terrain_builder.dart';

/// Assembles the spatial seascape [Scene3d]: synthesized seafloor, water
/// surface, the 3D swim path, and entry/exit pins, with a 3D scrub path so
/// the cursor follows the diver along the route. Pure; renders through the
/// shared renderer.
class SpatialGeometryService {
  static const double _padFraction = 0.25;
  static const double _minPadMeters = 2.0;

  const SpatialGeometryService();

  Scene3d build(ReckonedPath path, {double? siteMaxDepth}) {
    if (path.points.length < 2) {
      return const Scene3d(
        layers: [],
        markers: [],
        bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
      );
    }

    final maxDepth = math.max(math.max(path.maxDepth, siteMaxDepth ?? 0), 1.0);
    final padE = math.max(path.eastSpan * _padFraction, _minPadMeters);
    final padN = math.max(path.northSpan * _padFraction, _minPadMeters);
    final minE = path.minEast - padE, maxE = path.maxEast + padE;
    final minN = path.minNorth - padN, maxN = path.maxNorth + padN;

    final proj = SpatialProjection(
      minEast: minE,
      maxEast: maxE,
      minNorth: minN,
      maxNorth: maxN,
      maxDepth: maxDepth,
    );

    final terrain = TerrainBuilder.build(
      path: path,
      projection: proj,
      minEast: minE,
      maxEast: maxE,
      minNorth: minN,
      maxNorth: maxN,
    );
    final ribbon = SpatialPathBuilder.buildRibbon(path, proj);
    final entryPin = SpatialPathBuilder.buildPin(
      path.points.first,
      proj,
      isEntry: true,
    );
    final exitPin = SpatialPathBuilder.buildPin(
      path.points.last,
      proj,
      isEntry: false,
    );

    final zHalf = proj.zHalfExtent + SceneBounds.zHalfWidth;
    final bounds = SceneBounds(
      durationSeconds: path.durationSeconds,
      maxDepthMeters: maxDepth,
      sceneMinY: -SceneBounds.ySpan,
      sceneMaxY: 0,
      sceneMinZ: -zHalf,
      sceneMaxZ: zHalf,
    );

    final total = path.durationSeconds <= 0 ? 1.0 : path.durationSeconds;
    final scrub = ScrubPath(
      normalizedTimes: [for (final p in path.points) p.timeSeconds / total],
      xs: [for (final p in path.points) proj.xOf(p.east)],
      ys: [for (final p in path.points) proj.yOf(p.depth)],
      zs: [for (final p in path.points) proj.zOf(p.north)],
    );

    return Scene3d(
      // Back-to-front: seafloor, path, pins, translucent water on top.
      layers: [
        SceneLayer(terrain.terrain),
        SceneLayer(ribbon),
        SceneLayer(entryPin),
        SceneLayer(exitPin),
        SceneLayer(terrain.water),
      ],
      markers: const [],
      bounds: bounds,
      scrubPath: scrub,
    );
  }
}
