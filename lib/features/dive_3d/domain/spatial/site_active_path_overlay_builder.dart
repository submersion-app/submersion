import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/path_scene_markers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_path_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// A single active path (one dive, or one underwater route) rendered as a
/// scrubbable [ScrubPath] inside a SITE scene, plus the caption details the
/// UI shows alongside it.
class SiteActivePathOverlay {
  final ScrubPath scrubPath;

  /// The path's own ribbon and entry/exit pins. The site scene cannot be
  /// relied on to have drawn this path already: it draws only the most
  /// recent dives at the site, and never an underwater route, so without
  /// these the scrub cursor would slide across bare terrain.
  final List<SceneLayer> layers;

  /// The markers the recording device set along this path (issue #4231),
  /// placed with the site's projection like the ribbon itself. The site
  /// scene carries only its own markers, so these come with the overlay.
  final List<SceneMarker> markers;
  final PathProvenance provenance;
  final String? pathSourceLabel;

  const SiteActivePathOverlay({
    required this.scrubPath,
    this.layers = const [],
    this.markers = const [],
    required this.provenance,
    this.pathSourceLabel,
  });
}

/// Builds the scrub path for one dive's (or route's) reconstructed path,
/// projected with the SITE's own [projection] -- not a projection fit to the
/// path alone, the way `SpatialGeometryService.buildWithFrame` does for the
/// standalone dive scene. Reusing the site's projection is what lets this
/// path line up with the site's already-rendered terrain, markers and other
/// dive paths instead of landing at the wrong place or scale.
///
/// Mirrors the scrub path construction in `spatial_geometry_service.dart`
/// (`SpatialGeometryService.buildWithFrame`) and the per-dive path placement
/// already done for every dive in `site_seascape_geometry_service.dart`
/// (`SiteSeascapeGeometryService.buildWithLabels`) -- this just does the same
/// placement for one caller-chosen path and additionally turns it into a
/// [ScrubPath] for playback.
///
/// Returns null when [path] has fewer than two points, the same "nothing to
/// render" case the other two builders guard against.
SiteActivePathOverlay? buildSiteActivePathOverlay({
  required ReckonedPath path,
  required ({double east, double north}) anchor,
  required SpatialProjection projection,
}) {
  final placed = offsetReckonedPath(path, anchor);
  if (placed.points.length < 2) return null;

  final total = placed.durationSeconds <= 0 ? 1.0 : placed.durationSeconds;
  return SiteActivePathOverlay(
    scrubPath: ScrubPath(
      normalizedTimes: [for (final p in placed.points) p.timeSeconds / total],
      xs: [for (final p in placed.points) projection.xOf(p.east)],
      ys: [for (final p in placed.points) projection.yOf(p.depth)],
      zs: [for (final p in placed.points) projection.zOf(p.north)],
    ),
    layers: [
      SceneLayer(
        SpatialPathBuilder.buildRibbon(placed, projection),
        overlay: SceneOverlay.paths,
      ),
      SceneLayer(
        SpatialPathBuilder.buildPin(
          placed.points.first,
          projection,
          isEntry: true,
        ),
        overlay: SceneOverlay.paths,
      ),
      SceneLayer(
        SpatialPathBuilder.buildPin(
          placed.points.last,
          projection,
          isEntry: false,
        ),
        overlay: SceneOverlay.paths,
      ),
    ],
    markers: pathSceneMarkers(placed, projection),
    provenance: placed.provenance,
    pathSourceLabel: placed.sourceLabel,
  );
}

/// [scene] with [overlay]'s path drawn into it and its scrub path made the
/// one the cursor follows. The path layers go ahead of the water layer, the
/// same order the site scene gives its own dive paths, so the translucent
/// surface still paints over them. The path's own markers join the site's.
Scene3d sceneWithActivePath(Scene3d scene, SiteActivePathOverlay overlay) {
  bool isWater(SceneLayer l) => l.overlay == SceneOverlay.water;
  return Scene3d(
    layers: [
      ...scene.layers.where((l) => !isWater(l)),
      ...overlay.layers,
      ...scene.layers.where(isWater),
    ],
    markers: [...scene.markers, ...overlay.markers],
    bounds: scene.bounds,
    scrubPath: overlay.scrubPath,
  );
}
