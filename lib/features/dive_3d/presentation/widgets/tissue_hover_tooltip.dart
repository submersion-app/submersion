import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact readout for a hovered/tapped surface cell: time, compartment (with
/// N2 half-time), and saturation % with its state word. The values that the
/// tick-only axes deliberately omit live here.
class TissueHoverTooltip extends StatelessWidget {
  final TissuePick pick;
  final TissueSurfaceGrid grid;
  final int? runtimeSeconds;
  final TissueColorFn colorFn;

  const TissueHoverTooltip({
    super.key,
    required this.pick,
    required this.grid,
    required this.runtimeSeconds,
    required this.colorFn,
  });

  String _timeLabel(BuildContext context, double progress) {
    final runtime = runtimeSeconds;
    if (runtime == null) {
      return context.l10n.dive3d_tissue_tooltipProgress(
        (progress * 100).round(),
      );
    }
    final total = (progress * runtime).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _stateLabel(BuildContext context, TissueSaturationState state) {
    return switch (state) {
      TissueSaturationState.onGassing => context.l10n.dive3d_tissue_onGassing,
      TissueSaturationState.equilibrium =>
        context.l10n.dive3d_tissue_stateEquilibrium,
      TissueSaturationState.offGassing => context.l10n.dive3d_tissue_offGassing,
      TissueSaturationState.pastMValue =>
        context.l10n.dive3d_tissue_statePastMValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;
    final progress = grid.normalizedTimes[pick.col];
    final percent = grid.percentAt(pick.col, pick.comp);
    final state = tissueSaturationStateForPercent(percent);
    final swatch = colorFn(percent);
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_timeLabel(context, progress)}  ·  '
              '${l10n.dive3d_tissue_tooltipCompartment(grid.compartmentNumbers[pick.comp])}'
              '  ·  '
              '${l10n.dive3d_tissue_tooltipHalfTime(grid.halfTimesN2[pick.comp].round())}',
              style: text,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: swatch),
                const SizedBox(width: 6),
                Text(
                  '${l10n.dive3d_tissue_tooltipSaturation(percent.round())}'
                  '  —  ${_stateLabel(context, state)}',
                  style: text,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
