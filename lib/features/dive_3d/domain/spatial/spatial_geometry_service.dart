import 'dart:math' as math;

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_path_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/terrain_builder.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Assembles the spatial seascape [Scene3d]: seafloor, water surface, the
/// 3D swim path, and entry/exit pins, with a 3D scrub path so the cursor
/// follows the diver along the route. When a bathymetry [BathymetryGrid]
/// and its [GeoPoint] center are supplied the seafloor is real measured
/// terrain (never bent to cradle the path); otherwise it is the honest
/// synthesized reconstruction. Pure; renders through the shared renderer.
class SpatialGeometryService {
  static const double _padFraction = 0.25;
  static const double _minPadMeters = 2.0;

  const SpatialGeometryService();

  Scene3d build(
    ReckonedPath path, {
    double? siteMaxDepth,
    BathymetryGrid? grid,
    GeoPoint? gridCenter,
    ({double east, double north}) pathAnchor = (east: 0.0, north: 0.0),
  }) => buildWithFrame(
    path,
    siteMaxDepth: siteMaxDepth,
    grid: grid,
    gridCenter: gridCenter,
    pathAnchor: pathAnchor,
  ).scene;

  /// [build], plus the scene-frame numbers ([SeascapeAxisInputs]) the axes
  /// are derived from — captured here because only this method knows the
  /// union box of terrain and path.
  ({Scene3d scene, SeascapeAxisInputs frame}) buildWithFrame(
    ReckonedPath path, {
    double? siteMaxDepth,
    BathymetryGrid? grid,
    GeoPoint? gridCenter,
    ({double east, double north}) pathAnchor = (east: 0.0, north: 0.0),
  }) {
    if (path.points.length < 2) {
      return (
        scene: const Scene3d(
          layers: [],
          markers: [],
          bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
        ),
        frame: (
          minEast: 0.0,
          maxEast: 0.0,
          minNorth: 0.0,
          maxNorth: 0.0,
          maxDepth: 1.0,
        ),
      );
    }

    final useBathymetry = grid != null && gridCenter != null;
    final placed = useBathymetry ? offsetReckonedPath(path, pathAnchor) : path;

    final padE = math.max(placed.eastSpan * _padFraction, _minPadMeters);
    final padN = math.max(placed.northSpan * _padFraction, _minPadMeters);
    final double minE, maxE, minN, maxN, maxDepth;
    if (useBathymetry) {
      // The measured seafloor sets the frame; the path is a guest in it and
      // is never allowed to bend the terrain (honesty rule).
      final b = BathymetryTerrainBuilder.enuBounds(grid, gridCenter);
      minE = math.min(b.minEast, placed.minEast - padE);
      maxE = math.max(b.maxEast, placed.maxEast + padE);
      minN = math.min(b.minNorth, placed.minNorth - padN);
      maxN = math.max(b.maxNorth, placed.maxNorth + padN);
      maxDepth = math.max(
        math.max(placed.maxDepth, grid.maxDepthMeters),
        math.max(siteMaxDepth ?? 0, 1.0),
      );
    } else {
      minE = placed.minEast - padE;
      maxE = placed.maxEast + padE;
      minN = placed.minNorth - padN;
      maxN = placed.maxNorth + padN;
      maxDepth = math.max(math.max(placed.maxDepth, siteMaxDepth ?? 0), 1.0);
    }

    final proj = SpatialProjection(
      minEast: minE,
      maxEast: maxE,
      minNorth: minN,
      maxNorth: maxN,
      maxDepth: maxDepth,
    );

    final terrain = useBathymetry
        ? BathymetryTerrainBuilder.build(
            grid: grid,
            center: gridCenter,
            projection: proj,
          )
        : TerrainBuilder.build(
            path: placed,
            projection: proj,
            minEast: minE,
            maxEast: maxE,
            minNorth: minN,
            maxNorth: maxN,
          );
    final ribbon = SpatialPathBuilder.buildRibbon(placed, proj);
    final entryPin = SpatialPathBuilder.buildPin(
      placed.points.first,
      proj,
      isEntry: true,
    );
    final exitPin = SpatialPathBuilder.buildPin(
      placed.points.last,
      proj,
      isEntry: false,
    );

    final zHalf = proj.zHalfExtent + SceneBounds.zHalfWidth;
    final bounds = SceneBounds(
      durationSeconds: placed.durationSeconds,
      maxDepthMeters: maxDepth,
      sceneMinY: -SceneBounds.ySpan,
      sceneMaxY: 0,
      sceneMinZ: -zHalf,
      sceneMaxZ: zHalf,
    );

    final total = placed.durationSeconds <= 0 ? 1.0 : placed.durationSeconds;
    final scrub = ScrubPath(
      normalizedTimes: [for (final p in placed.points) p.timeSeconds / total],
      xs: [for (final p in placed.points) proj.xOf(p.east)],
      ys: [for (final p in placed.points) proj.yOf(p.depth)],
      zs: [for (final p in placed.points) proj.zOf(p.north)],
    );

    final scene = Scene3d(
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
    return (
      scene: scene,
      frame: (
        minEast: minE,
        maxEast: maxE,
        minNorth: minN,
        maxNorth: maxN,
        maxDepth: maxDepth,
      ),
    );
  }
}
