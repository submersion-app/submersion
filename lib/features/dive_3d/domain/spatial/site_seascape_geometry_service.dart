import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/grid_sampling.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_path_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/wall_highlight_builder.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One dive's reconstructed path placed in the site's local frame.
class SiteDivePathInput {
  final String diveId;
  final ReckonedPath path;
  final ({double east, double north}) anchor;

  const SiteDivePathInput({
    required this.diveId,
    required this.path,
    required this.anchor,
  });
}

/// A diver-placed annotation, flattened to plain sendable data for the
/// compute() boundary: the domain entity and its lat/lon stay UI-side.
class SiteFeatureMarkerInput {
  final String id;
  final String typeName;
  final String label;
  final ({double east, double north}) offset;

  /// Meters, when the diver recorded one; null drapes the marker on the
  /// sampled seafloor instead.
  final double? depthMeters;

  const SiteFeatureMarkerInput({
    required this.id,
    required this.typeName,
    required this.label,
    required this.offset,
    this.depthMeters,
  });
}

/// Another site whose pin falls inside the fetched terrain.
class NearbySiteInput {
  final String siteId;
  final String name;
  final ({double east, double north}) offset;

  const NearbySiteInput({
    required this.siteId,
    required this.name,
    required this.offset,
  });
}

/// Everything the site seascape scene needs, in plain sendable data (the
/// whole input crosses the compute() isolate boundary for large grids).
class SiteSeascapeInput {
  final BathymetryGrid grid;
  final GeoPoint center;
  final String siteName;
  final double? siteMaxDepth;
  final List<SiteDivePathInput> divePaths;
  final List<NearbySiteInput> nearbySites;
  final List<SiteFeatureMarkerInput> features;
  final SeascapeAppearance appearance;
  final double displayUnitInMeters;
  final String depthSymbol;

  /// The stitched imagery's mercator mapping when the surface drapes map
  /// tiles; null renders the depth ramp. Plain data so the whole input
  /// still crosses compute().
  final TerrainImageryFrame? imageryFrame;

  const SiteSeascapeInput({
    required this.grid,
    required this.center,
    required this.siteName,
    this.siteMaxDepth,
    required this.divePaths,
    required this.nearbySites,
    this.features = const [],
    this.appearance = const SeascapeAppearance(),
    this.displayUnitInMeters = 1.0,
    this.depthSymbol = 'm',
    this.imageryFrame,
  });
}

/// Assembles the site-level seascape: real terrain, every reconstructed
/// dive path draped in place (never deforming the measured seafloor),
/// the site pin with its recorded max depth, and nearby-site markers.
class SiteSeascapeGeometryService {
  static const Color _sitePinColor = Color(0xFFF43F5E);
  static const double _markerFloat = 0.15;
  static const double _surfaceHeadroom = 0.6;

  const SiteSeascapeGeometryService();

  Scene3d build(SiteSeascapeInput input) => buildWithLabels(input).scene;

  ({Scene3d scene, List<ContourLabelSpec> contourLabels}) buildWithLabels(
    SiteSeascapeInput input,
  ) {
    final box = BathymetryTerrainBuilder.enuBounds(input.grid, input.center);
    final maxDepth = math.max(
      math.max(input.grid.maxDepthMeters, input.siteMaxDepth ?? 0),
      1.0,
    );
    final proj = SpatialProjection(
      minEast: box.minEast,
      maxEast: box.maxEast,
      minNorth: box.minNorth,
      maxNorth: box.maxNorth,
      maxDepth: maxDepth,
    );

    final terrain = BathymetryTerrainBuilder.build(
      grid: input.grid,
      center: input.center,
      projection: proj,
      rampMaxDepthMeters: input.appearance.rampMaxDepthMeters,
      rampBanded: input.appearance.rampBanded,
      imageryFrame: input.imageryFrame,
      surfaceMode: input.appearance.surfaceMode,
    );
    final contours = buildContourLayers(
      grid: input.grid,
      center: input.center,
      projection: proj,
      appearance: input.appearance,
      displayUnitInMeters: input.displayUnitInMeters,
      depthSymbol: input.depthSymbol,
    );
    final wallMesh = buildWallHighlightMesh(
      grid: input.grid,
      center: input.center,
      projection: proj,
      thresholdDeg: input.appearance.wallAngleDeg,
    );

    final layers = <SceneLayer>[SceneLayer(terrain.terrain)];
    layers.addAll(contours.layers);
    if (wallMesh != null) {
      layers.add(
        SceneLayer(
          wallMesh,
          overlay: SceneOverlay.steepWalls,
          drapedOnTerrain: true,
        ),
      );
    }
    for (final d in input.divePaths) {
      final placed = offsetReckonedPath(d.path, d.anchor);
      if (placed.points.length < 2) continue;
      layers
        ..add(
          SceneLayer(
            SpatialPathBuilder.buildRibbon(placed, proj),
            overlay: SceneOverlay.paths,
          ),
        )
        ..add(
          SceneLayer(
            SpatialPathBuilder.buildPin(
              placed.points.first,
              proj,
              isEntry: true,
            ),
            overlay: SceneOverlay.paths,
          ),
        )
        ..add(
          SceneLayer(
            SpatialPathBuilder.buildPin(
              placed.points.last,
              proj,
              isEntry: false,
            ),
            overlay: SceneOverlay.paths,
          ),
        );
    }
    layers
      ..add(SceneLayer(_sitePin(proj, input.siteMaxDepth ?? maxDepth)))
      ..add(SceneLayer(terrain.water, overlay: SceneOverlay.water));

    final markers = <SceneMarker>[
      SceneMarker(
        kind: SceneMarkerKind.site,
        refId: null,
        label: input.siteName,
        x: proj.xOf(0),
        y: _markerFloat,
        z: proj.zOf(0),
        timestampSeconds: 0,
      ),
      for (final n in input.nearbySites)
        SceneMarker(
          kind: SceneMarkerKind.nearbySite,
          refId: n.siteId,
          label: n.name,
          x: proj.xOf(n.offset.east),
          y: _markerFloat,
          z: proj.zOf(n.offset.north),
          timestampSeconds: 0,
        ),
      for (final f in input.features)
        SceneMarker(
          kind: SceneMarkerKind.siteFeature,
          refId: f.id,
          label: f.label.isNotEmpty ? f.label : f.typeName,
          x: proj.xOf(f.offset.east),
          y: f.depthMeters != null
              ? proj.yOf(f.depthMeters!)
              : _featureY(input.grid, input.center, f.offset, proj),
          z: proj.zOf(f.offset.north),
          timestampSeconds: 0,
        ),
    ];

    final zHalf = proj.zHalfExtent + SceneBounds.zHalfWidth;
    final scene = Scene3d(
      layers: layers,
      markers: markers,
      bounds: SceneBounds(
        durationSeconds: 1,
        maxDepthMeters: maxDepth,
        sceneMinY: -SceneBounds.ySpan,
        sceneMaxY: _surfaceHeadroom,
        sceneMinZ: -zHalf,
        sceneMaxZ: zHalf,
      ),
    );
    return (scene: scene, contourLabels: contours.labels);
  }

  /// Scene y for a feature with no recorded depth: the measured seafloor
  /// under it, so the marker sits ON the terrain rather than floating at
  /// an invented depth. Falls back to the surface float when the grid has
  /// nothing there (nodata, land, or outside).
  double _featureY(
    BathymetryGrid grid,
    GeoPoint center,
    ({double east, double north}) offset,
    SpatialProjection proj,
  ) {
    final lat =
        center.latitude +
        offset.north / BathymetryTerrainBuilder.metersPerDegLat;
    final lon =
        center.longitude +
        offset.east / metersPerDegreeLongitude(center.latitude);
    final depth = sampleGridDepth(grid, lat, lon);
    return depth == null ? _markerFloat : proj.yOf(depth);
  }

  /// A thin vertical quad from the surface down to the site's recorded max
  /// depth at the scene center — the "you are here, this deep" pin.
  MeshData _sitePin(SpatialProjection proj, double pinDepth) {
    const halfWidth = 0.05;
    final x = proj.xOf(0);
    final z = proj.zOf(0);
    final yBottom = proj.yOf(pinDepth);
    final positions = Float32List.fromList([
      x - halfWidth,
      0,
      z,
      x + halfWidth,
      0,
      z,
      x - halfWidth,
      yBottom,
      z,
      x + halfWidth,
      yBottom,
      z,
    ]);
    final colors = Float32List(4 * 3);
    for (var i = 0; i < 4; i++) {
      colors[i * 3] = _sitePinColor.r;
      colors[i * 3 + 1] = _sitePinColor.g;
      colors[i * 3 + 2] = _sitePinColor.b;
    }
    return MeshData(
      positions: positions,
      indices: Uint32List.fromList([0, 1, 2, 1, 3, 2]),
      colors: colors,
      opacity: 0.85,
    );
  }
}
