import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
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

/// The 3D extrusion of the Subsurface tissue loading heat map for a dive.
/// Uses the same DecoStatus series, the same subsurfacePercentage value, and
/// the diver's selected tissue color scheme, so it reads as the 2D graph in
/// three dimensions. Null when no analysis exists.
final tissue3dSceneProvider = FutureProvider.family<Scene3d?, String>((
  ref,
  diveId,
) async {
  final statuses = await ref.watch(tissueDecoStatusesProvider(diveId).future);
  if (statuses.length < 2) return null;
  final colorFn = colorFnForScheme(ref.watch(tissueColorSchemeProvider));
  return SubsurfaceTissueBuilder.build(statuses, colorFn: colorFn);
});
