import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/nav_track/domain/nav_track_path_adapter.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The standalone route seascape (spec
/// 2026-09-10-underwater-nav-track-design.md, "Route seascape"): a route's
/// own 3D view, with no dive required.
///
/// Mirrors `spatialGeometryProvider`'s `buildWithFrame` call (dive_3d's
/// `spatial_providers.dart`) so the two scenes render with the same terrain
/// and path geometry rules; real terrain from `bathymetryGridProvider` when
/// the route is anchored, else the synthesized fallback (null grid) the
/// dive scene already falls back to when it has no coordinates.
final navTrackSceneProvider =
    FutureProvider.family<SpatialSceneResult?, String>((ref, trackId) async {
      final route = await ref.watch(navTrackByIdProvider(trackId).future);
      if (route == null || route.points.length < 2) return null;

      final path = NavTrackPathAdapter.toReckonedPath(route);
      if (path.points.length < 2) return null;

      final anchor = route.anchor;
      BathymetryGrid? grid;
      if (anchor != null) {
        grid = await ref.watch(
          bathymetryGridProvider(BathymetryRepository.quantize(anchor)).future,
        );
      }

      final appearance = ref.watch(
        settingsProvider.select((s) => s.seascapeAppearance),
      );
      final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));

      final built = const SpatialGeometryService().buildWithFrame(
        path,
        siteMaxDepth: null,
        grid: grid,
        gridCenter: grid == null ? null : anchor,
        pathAnchor: (east: 0.0, north: 0.0),
        appearance: appearance,
        displayUnitInMeters: depthUnit == DepthUnit.feet ? 0.3048 : 1.0,
        depthSymbol: depthUnit.symbol,
        imageryFrame: null,
      );

      return SpatialSceneResult(
        scene: built.scene,
        bathymetrySourceId: grid?.sourceId,
        bathymetryResolutionMeters: grid?.resolutionMeters,
        axisInputs: built.frame,
        grid: grid,
        contourLabels: built.contourLabels,
        pathProvenance: path.provenance,
        pathSourceLabel: path.sourceLabel,
      );
    });
