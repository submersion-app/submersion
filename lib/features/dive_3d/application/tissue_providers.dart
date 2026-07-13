import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The per-sample decompression status series for a dive's active source -
/// the same data that feeds the 2D tissue heat map.
final tissueDecoStatusesProvider =
    FutureProvider.family<List<DecoStatus>, String>((ref, diveId) async {
      final analysis = await ref.watch(
        sourceProfileAnalysisProvider((
          diveId: diveId,
          sourceId: ref.watch(activeDiveSourceProvider(diveId)),
        )).future,
      );
      return analysis?.decoStatuses ?? const [];
    });

/// The active tissue color scheme (matches the 2D heat map's coloring).
final tissueColorSchemeProvider = Provider<TissueColorScheme>(
  (ref) => ref.watch(settingsProvider).tissueColorScheme,
);

/// The Scene3d + TissueSurfaceGrid for a dive, built in a single pass so the
/// mesh, the draped wireframe, and the hover picker never drift apart. Uses the
/// same DecoStatus series, the same subsurfacePercentage value, and the diver's
/// selected tissue color scheme, so it reads as the 2D graph in three
/// dimensions. Null when there is nothing to render - mirroring
/// [SubsurfaceTissueBuilder.buildResult]'s bail-out - i.e. fewer than 2
/// statuses, or statuses that carry no tissue compartments.
final tissueSurfaceProvider =
    FutureProvider.family<TissueSurfaceResult?, String>((ref, diveId) async {
      final statuses = await ref.watch(
        tissueDecoStatusesProvider(diveId).future,
      );
      if (statuses.length < 2 || statuses.first.compartments.isEmpty) {
        return null;
      }
      final colorFn = colorFnForScheme(ref.watch(tissueColorSchemeProvider));
      return SubsurfaceTissueBuilder.buildResult(statuses, colorFn: colorFn);
    });

/// The 3D extrusion of the tissue heat map (derived from [tissueSurfaceProvider]).
final tissue3dSceneProvider = FutureProvider.family<Scene3d?, String>(
  (ref, diveId) async =>
      (await ref.watch(tissueSurfaceProvider(diveId).future))?.scene,
);

/// The topology-preserving grid for the draped wireframe + hover picking.
final tissueSurfaceGridProvider =
    FutureProvider.family<TissueSurfaceGrid?, String>(
      (ref, diveId) async =>
          (await ref.watch(tissueSurfaceProvider(diveId).future))?.grid,
    );

/// Dive runtime in seconds, used to convert the tissue X axis (0..1 progress)
/// into a wall-clock mm:ss in the hover tooltip. Null when unknown (the tooltip
/// then shows "% of dive").
final tissueRuntimeSecondsProvider = FutureProvider.family<int?, String>((
  ref,
  diveId,
) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  return dive?.effectiveRuntime?.inSeconds;
});
