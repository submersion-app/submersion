import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

/// A single active path (one dive, or one underwater route) rendered as a
/// scrubbable [ScrubPath] inside a SITE scene, plus the caption details the
/// UI shows alongside it.
class SiteActivePathOverlay {
  final ScrubPath scrubPath;
  final PathProvenance provenance;
  final String? pathSourceLabel;

  const SiteActivePathOverlay({
    required this.scrubPath,
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
    provenance: placed.provenance,
    pathSourceLabel: placed.sourceLabel,
  );
}
