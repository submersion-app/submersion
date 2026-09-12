import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';
import 'package:submersion/features/bathymetry/presentation/terrain_imagery_providers.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/dead_reckoning_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/nav_track_path_adapter.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Whether the dive's 3D seascape should draw the linked measured route
/// (the default) rather than the dead-reckoned estimate, when both are
/// available. Purely a display toggle for the "Show route" button on
/// `SpatialSitePage` -- it never affects which path is *stored* or linked,
/// only which one `spatialReckonedPathProvider` returns for this viewing.
/// True (show the route) unless a diver has explicitly flipped it, so a
/// dive with no route linked behaves exactly as before this toggle existed.
final showMeasuredRouteProvider = StateProvider.family<bool, String>(
  (ref, diveId) => true,
);

/// The reconstructed swim path for a dive: a linked underwater route when
/// one exists, has enough points, and [showMeasuredRouteProvider] has not
/// been switched off, else dead reckoning, else null when the dive has no
/// usable profile either.
final spatialReckonedPathProvider =
    FutureProvider.family<ReckonedPath?, String>((ref, diveId) async {
      final route = await ref.watch(
        primaryNavTrackForDiveProvider(diveId).future,
      );
      final showMeasuredRoute = ref.watch(showMeasuredRouteProvider(diveId));
      if (route != null && route.points.length >= 2 && showMeasuredRoute) {
        // The raw sample count is not enough: toReckonedPath truncates to
        // the active underwater/surfaceReckoned range, which can legitimately
        // adapt down to fewer than two points (e.g. almost the whole
        // recording turns out to be a pre-dive/post-dive fix run with
        // barely any real underwater samples). Only an adapted path with at
        // least two points is usable; otherwise fall through to dead
        // reckoning below rather than returning a degenerate measured path.
        final adapted = NavTrackPathAdapter.toReckonedPath(route);
        if (adapted.points.length >= 2) {
          return adapted;
        }
      }

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

  /// Labeled contour levels (real bathymetry only; empty for the
  /// synthesized fallback).
  final List<ContourLabelSpec> contourLabels;

  /// The stitched terrain imagery when the surface mode drapes map tiles
  /// and the mosaic has resolved; attached UI-side (never crosses the
  /// compute() isolate).
  final TerrainImagery? imagery;

  /// Where the swim path's shape came from: a linked measured route, dead
  /// reckoning, or the straight-line fallback. Drives the path caption.
  final PathProvenance pathProvenance;

  /// A caption detail for [PathProvenance.measured] paths (e.g. the
  /// route's source label), or null when none is available.
  final String? pathSourceLabel;

  const SpatialSceneResult({
    required this.scene,
    this.bathymetrySourceId,
    this.bathymetryResolutionMeters,
    this.axisInputs,
    this.grid,
    this.contourLabels = const [],
    this.imagery,
    this.pathProvenance = PathProvenance.deadReckoned,
    this.pathSourceLabel,
  });
}

typedef _SpatialBuildInput = ({
  ReckonedPath path,
  double? siteMaxDepth,
  BathymetryGrid? grid,
  GeoPoint? gridCenter,
  ({double east, double north}) pathAnchor,
  SeascapeAppearance appearance,
  double displayUnitInMeters,
  String depthSymbol,
  TerrainImageryFrame? imageryFrame,
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
      // A linked, primary route carries its own georeferenced start point
      // (`anchor`), set by the diver on the alignment page; when the scene
      // is drawing that measured route, use it in place of the dive's own
      // entry fix, mirroring what siteSeascapeProvider already does for the
      // same route one level up. Without this a manually aligned route
      // renders at the dive's entry location instead of where the diver
      // actually put it.
      GeoPoint? entry;
      if (path.provenance == PathProvenance.measured) {
        final route = await ref.watch(
          primaryNavTrackForDiveProvider(diveId).future,
        );
        entry = route?.anchor;
      }
      entry ??= dive?.entryLocation;
      final anchor = (grid != null && center != null && entry != null)
          ? enuOffsetMeters(center, entry)
          : (east: 0.0, north: 0.0);

      // Terrain appearance and the depth unit shape the geometry (contour
      // levels, ramp colors, wall threshold).
      final appearance = ref.watch(
        settingsProvider.select((s) => s.seascapeAppearance),
      );
      final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));

      // Imagery drape: non-blocking; depth colors render while the mosaic
      // loads and the scene rebuilds when it lands.
      TerrainImagery? imagery;
      if (appearance.surfaceMode != SeascapeSurfaceMode.depth &&
          grid != null &&
          center != null) {
        final mapStyle = ref.watch(settingsProvider.select((s) => s.mapStyle));
        final cell = BathymetryRepository.quantize(center);
        imagery = ref
            .watch(
              terrainImageryProvider((
                lat: cell.lat,
                lon: cell.lon,
                style: mapStyle,
              )),
            )
            .valueOrNull;
      }

      final input = (
        path: path,
        siteMaxDepth: siteMaxDepth,
        grid: grid,
        gridCenter: grid == null ? null : center,
        pathAnchor: anchor,
        appearance: appearance,
        displayUnitInMeters: depthUnit == DepthUnit.feet ? 0.3048 : 1.0,
        depthSymbol: depthUnit.symbol,
        imageryFrame: imagery?.frame,
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
        contourLabels: built.contourLabels,
        imagery: imagery,
        pathProvenance: path.provenance,
        pathSourceLabel: path.sourceLabel,
      );
    });

({
  Scene3d scene,
  SeascapeAxisInputs frame,
  List<ContourLabelSpec> contourLabels,
})
_buildSpatial(_SpatialBuildInput input) =>
    const SpatialGeometryService().buildWithFrame(
      input.path,
      siteMaxDepth: input.siteMaxDepth,
      grid: input.grid,
      gridCenter: input.gridCenter,
      pathAnchor: input.pathAnchor,
      appearance: input.appearance,
      displayUnitInMeters: input.displayUnitInMeters,
      depthSymbol: input.depthSymbol,
      imageryFrame: input.imageryFrame,
    );
