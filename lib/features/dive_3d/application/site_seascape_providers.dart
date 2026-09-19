import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_lod.dart';
import 'package:submersion/features/bathymetry/presentation/terrain_imagery_providers.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Terminal states for the site seascape. The provider ALWAYS resolves to
/// one of these — a null/silent-spinner path does not exist (PR #659).
sealed class SiteSeascapeState {
  const SiteSeascapeState();
}

class SiteSeascapeReady extends SiteSeascapeState {
  final Scene3d scene;
  final String sourceId;
  final double resolutionMeters;
  final SeascapeAxisInputs axisInputs;

  /// The (downsampled) grid the terrain was built from — hover inspection
  /// reads per-cell coordinates and depth from it.
  final BathymetryGrid grid;

  /// Labeled contour levels with their scene-space anchor candidates; the
  /// chrome painter picks the camera-nearest anchor per frame.
  final List<ContourLabelSpec> contourLabels;

  /// The stitched terrain imagery when the surface mode drapes map tiles
  /// and the mosaic has resolved; attached UI-side (never crosses the
  /// compute() isolate). The viewport samples image + white texel from it.
  final TerrainImagery? imagery;

  const SiteSeascapeReady({
    required this.scene,
    required this.sourceId,
    required this.resolutionMeters,
    required this.axisInputs,
    required this.grid,
    this.contourLabels = const [],
    this.imagery,
  });
}

class SiteSeascapeNoCoordinates extends SiteSeascapeState {
  const SiteSeascapeNoCoordinates();
}

class SiteSeascapeNoData extends SiteSeascapeState {
  const SiteSeascapeNoData();
}

/// Heaviest sites stay readable: newest dives first, capped.
const int _maxDivePaths = 30;

/// Below this cell count the scene builds synchronously (widget-test
/// FakeAsync deadlock rule); above it, in a compute() isolate.
const int _isolateCellThreshold = 4000;

final siteSeascapeProvider = FutureProvider.family<SiteSeascapeState, String>((
  ref,
  siteId,
) async {
  final site = await ref.watch(siteProvider(siteId).future);
  final center = site?.location;
  if (site == null || center == null) {
    return const SiteSeascapeNoCoordinates();
  }

  final grid = await ref.watch(
    bathymetryGridProvider(BathymetryRepository.quantize(center)).future,
  );
  if (grid == null) return const SiteSeascapeNoData();

  final allDives = await ref.watch(divesProvider.future);
  final atSite = allDives.where((d) => d.site?.id == siteId).toList()
    ..sort(
      (a, b) =>
          (b.entryTime ?? b.dateTime).compareTo(a.entryTime ?? a.dateTime),
    );
  // Reconstruct all paths concurrently: each resolution touches the DB and
  // does dead-reckoning work, so N sequential awaits would stack latency.
  final kept = atSite.take(_maxDivePaths).toList();
  final paths = await Future.wait(
    kept.map((d) => ref.watch(spatialReckonedPathProvider(d.id).future)),
  );
  final divePaths = <SiteDivePathInput>[];
  for (var i = 0; i < kept.length; i++) {
    final path = paths[i];
    if (path == null || path.points.length < 2) continue;
    final entry = kept[i].entryLocation;
    divePaths.add(
      SiteDivePathInput(
        diveId: kept[i].id,
        path: path,
        anchor: entry == null
            ? (east: 0.0, north: 0.0)
            : enuOffsetMeters(center, entry),
      ),
    );
  }

  final box = BathymetryTerrainBuilder.enuBounds(grid, center);
  final sites = await ref.watch(sitesProvider.future);
  final nearby = <NearbySiteInput>[];
  for (final s in sites) {
    final sLoc = s.location;
    if (s.id == siteId || sLoc == null) continue;
    final off = enuOffsetMeters(center, sLoc);
    final inside =
        off.east >= box.minEast &&
        off.east <= box.maxEast &&
        off.north >= box.minNorth &&
        off.north <= box.maxNorth;
    if (inside) {
      nearby.add(NearbySiteInput(siteId: s.id, name: s.name, offset: off));
    }
  }

  // Diver-placed annotations, flattened to the site's local frame so the
  // whole input still crosses compute().
  final features =
      ref.watch(siteFeaturesProvider(siteId)).valueOrNull ?? const [];
  final featureInputs = [
    for (final f in features)
      SiteFeatureMarkerInput(
        id: f.id,
        typeName: f.typeName,
        label: f.name,
        offset: enuOffsetMeters(center, GeoPoint(f.latitude, f.longitude)),
        depthMeters: f.depthMeters,
      ),
  ];

  // Terrain appearance and the depth unit shape the geometry (contour
  // levels, ramp colors, wall threshold), so the scene rebuilds when the
  // diver changes either.
  final appearance = ref.watch(
    settingsProvider.select((s) => s.seascapeAppearance),
  );
  final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));

  // Imagery drape: non-blocking. While the mosaic loads (or offline) the
  // scene renders with depth colors and rebuilds when it lands.
  TerrainImagery? imagery;
  if (appearance.surfaceMode != SeascapeSurfaceMode.depth) {
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

  final input = SiteSeascapeInput(
    grid: grid,
    center: center,
    siteName: site.name,
    siteMaxDepth: site.maxDepth,
    divePaths: divePaths,
    nearbySites: nearby,
    features: featureInputs,
    appearance: appearance,
    displayUnitInMeters: depthUnit == DepthUnit.feet ? 0.3048 : 1.0,
    depthSymbol: depthUnit.symbol,
    imageryFrame: imagery?.frame,
  );
  final built = grid.rows * grid.cols > _isolateCellThreshold
      ? await compute(_buildScene, input)
      : const SiteSeascapeGeometryService().buildWithLabels(input);
  // Mirrors SiteSeascapeGeometryService's depth budget so the axes and the
  // terrain agree on the scene frame: scaled from the measured grid alone,
  // not the site's recorded max depth (which may sit outside this box).
  final maxDepth = math.max(grid.maxDepthMeters, 1.0);
  return SiteSeascapeReady(
    scene: built.scene,
    sourceId: grid.sourceId,
    resolutionMeters: grid.resolutionMeters,
    grid: grid,
    contourLabels: built.contourLabels,
    imagery: imagery,
    axisInputs: (
      minEast: box.minEast,
      maxEast: box.maxEast,
      minNorth: box.minNorth,
      maxNorth: box.maxNorth,
      maxDepth: maxDepth,
    ),
  );
});

({Scene3d scene, List<ContourLabelSpec> contourLabels}) _buildScene(
  SiteSeascapeInput input,
) => const SiteSeascapeGeometryService().buildWithLabels(input);

/// An additional, finer terrain patch layered on top of the always-loaded
/// base square when the diver zooms in past `overview` (see
/// `bathymetry_lod.dart`). [detailLimitReached] flags the case where the
/// `fine` stage's grid came back no meaningfully sharper than the base
/// grid -- the source simply has nothing finer for this spot -- so the UI
/// can show a quiet "no more detail here" hint instead of implying more
/// zoom would help.
class SiteSeascapePatchLayer {
  final SceneLayer layer;
  final BathymetryLodStage stage;
  final bool detailLimitReached;

  const SiteSeascapePatchLayer({
    required this.layer,
    required this.stage,
    required this.detailLimitReached,
  });
}

/// How much finer the `fine` stage's patch grid must be than the base grid
/// to count as genuinely more detail. A simple, documented heuristic (not a
/// real resolution comparison across sources): a patch declaring at least
/// 10% finer resolution than the base grid is treated as real extra detail,
/// anything coarser as the source topping out.
const double _detailLimitResolutionRatio = 0.9;

/// Isolate input for [_buildPatchTerrain] -- a plain, sendable bundle of
/// everything [BathymetryTerrainBuilder.build] needs, mirroring how
/// [SiteSeascapeInput] already crosses the [compute] boundary for the base
/// terrain build.
class _PatchTerrainInput {
  final BathymetryGrid grid;
  final GeoPoint center;
  final SpatialProjection projection;
  final double? rampMaxDepthMeters;
  final bool rampBanded;
  final SeascapeSurfaceMode surfaceMode;

  const _PatchTerrainInput({
    required this.grid,
    required this.center,
    required this.projection,
    required this.rampMaxDepthMeters,
    required this.rampBanded,
    required this.surfaceMode,
  });
}

MeshData _buildPatchTerrain(_PatchTerrainInput input) =>
    BathymetryTerrainBuilder.build(
      grid: input.grid,
      center: input.center,
      projection: input.projection,
      rampMaxDepthMeters: input.rampMaxDepthMeters,
      rampBanded: input.rampBanded,
      surfaceMode: input.surfaceMode,
    ).terrain;

/// The additional LOD patch layer for one site at the current LOD [stage]
/// (see `bathymetry_lod.dart`), built in the SAME coordinate frame as the
/// base scene's terrain -- it must reuse the base scene's
/// [SpatialProjection] bounds (not derive its own from the smaller patch
/// grid's extent), or the patch mesh would be scaled inconsistently with the
/// base terrain it sits on top of. Returns null whenever there is nothing
/// additional to render: the `overview` stage (no patch), the base scene not
/// ready yet, or no patch grid available (a source that cannot deliver
/// anything for this span is rejected the same way the base fetch would
/// reject it -- see `BathymetryResolver.resolve`'s quality floors).
///
/// Keyed by the discrete [BathymetryLodStage], not the raw zoom scalar --
/// computed at the call site (`SiteTerrainPane`) via
/// [bathymetryLodStageForZoom] -- so every settled zoom within one stage's
/// range shares the same cache entry instead of minting a new, never-freed
/// one per pixel of scroll. `autoDispose` for the same reason
/// [bathymetryPatchGridProvider] is: a site/stage combination no longer
/// being watched frees its (comparatively heavy, per-site) mesh.
final siteSeascapePatchLayerProvider = FutureProvider.autoDispose
    .family<
      SiteSeascapePatchLayer?,
      ({String siteId, BathymetryLodStage stage})
    >((ref, request) async {
      if (request.stage == BathymetryLodStage.overview) return null;

      final base = await ref.watch(siteSeascapeProvider(request.siteId).future);
      if (base is! SiteSeascapeReady) return null;

      final site = await ref.watch(siteProvider(request.siteId).future);
      final center = site?.location;
      if (center == null) return null;

      final patchGrid = await ref.watch(
        bathymetryPatchGridProvider((
          lat: center.latitude,
          lon: center.longitude,
          spanMeters: request.stage.spanMeters,
        )).future,
      );
      if (patchGrid == null) return null;

      final appearance = ref.watch(
        settingsProvider.select((s) => s.seascapeAppearance),
      );
      final proj = SpatialProjection(
        minEast: base.axisInputs.minEast,
        maxEast: base.axisInputs.maxEast,
        minNorth: base.axisInputs.minNorth,
        maxNorth: base.axisInputs.maxNorth,
        maxDepth: base.axisInputs.maxDepth,
      );
      final terrainInput = _PatchTerrainInput(
        grid: patchGrid,
        center: center,
        projection: proj,
        rampMaxDepthMeters: appearance.rampMaxDepthMeters,
        rampBanded: appearance.rampBanded,
        surfaceMode: appearance.surfaceMode,
      );
      // Mirrors the base terrain build's isolate offload (siteSeascapeProvider
      // above): a patch grid is capped at 120x120 (BathymetryRepository.
      // maxGridDim) = 14400 cells, well past _isolateCellThreshold, so
      // building it synchronously on the UI isolate would jank every zoom
      // settle.
      final mesh = patchGrid.rows * patchGrid.cols > _isolateCellThreshold
          ? await compute(_buildPatchTerrain, terrainInput)
          : _buildPatchTerrain(terrainInput);

      final detailLimitReached =
          request.stage == BathymetryLodStage.fine &&
          patchGrid.resolutionMeters >=
              base.resolutionMeters * _detailLimitResolutionRatio;

      return SiteSeascapePatchLayer(
        // NOT drapedOnTerrain: the patch fully overlaps a REGION of the base
        // terrain (same footprint, finer grid), it doesn't ride alongside it
        // the way a thin contour/wall drape does. Merging two independent,
        // near-coplanar opaque surfaces into partitionLayers' per-triangle
        // depth sort z-fights them (confirmed visually: a torn, flickering
        // mix of both meshes' triangles). Painting the patch as a plain
        // "rest" layer -- unconditionally on top, whole, after the merged
        // group -- has no such artifact: the patch cleanly covers the base
        // terrain underneath it. The tradeoff (documented, accepted): a
        // draped contour/wall overlay drawn against the base terrain will
        // not correctly hide behind the patch where the two overlap; that
        // is a pre-existing limitation of the "two separate zones, no seam
        // blending" design (see issue #2158), not a regression here.
        layer: SceneLayer(mesh),
        stage: request.stage,
        detailLimitReached: detailLimitReached,
      );
    });
