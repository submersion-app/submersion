import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_lod.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The terrain pane's caption naming the seafloor source, its resolution
/// and the active level-of-detail stage.
///
/// Surfaces the active LOD stage (see bathymetry_lod.dart) so a diver can
/// tell why the terrain just got sharper (or why it stopped getting sharper)
/// without needing to know the underlying zoom threshold. The span respects
/// the diver's own depth unit, like every other measurement on the pane
/// (legend, axes).
class SeascapeSourceChip extends StatelessWidget {
  const SeascapeSourceChip({
    super.key,
    required this.sourceId,
    required this.resolutionMeters,
    required this.stage,
    required this.depthUnit,
  });

  final String sourceId;
  final double resolutionMeters;
  final BathymetryLodStage stage;
  final DepthUnit depthUnit;

  @override
  Widget build(BuildContext context) {
    final stageName = switch (stage) {
      BathymetryLodStage.overview =>
        context.l10n.dive3d_seascape_lodStageOverview,
      BathymetryLodStage.medium => context.l10n.dive3d_seascape_lodStageMedium,
      BathymetryLodStage.fine => context.l10n.dive3d_seascape_lodStageFine,
      BathymetryLodStage.superFine =>
        context.l10n.dive3d_seascape_lodStageSuperFine,
    };
    final spanDisplay = DepthUnit.meters.convert(stage.spanMeters, depthUnit);
    final stageLabelText = context.l10n.dive3d_seascape_lodStageLabel(
      stageName,
      '${spanDisplay.round()} ${depthUnit.symbol}',
    );
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${context.l10n.dive3d_seascape_seafloorSource(bathymetrySourceDisplayName(sourceId), resolutionMeters.round().toString())} · $stageLabelText',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
