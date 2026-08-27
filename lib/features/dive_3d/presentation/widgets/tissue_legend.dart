import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Explains how to read the 3D tissue heat map: the same on-gassing ->
/// off-gassing color scale as the 2D graph (now driving height too), the
/// M-value limit plane, and the two axes. Kept compact and always visible.
class TissueLegend extends StatelessWidget {
  final TissueColorFn colorFn;

  const TissueLegend({super.key, required this.colorFn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;

    // Sample the same color scale as the 2D heat map legend.
    final colors = <Color>[for (var i = 0; i <= 20; i++) colorFn(i * 5.0)];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.dive3d_tissue_onGassing, style: text),
                const SizedBox(width: 4),
                Container(
                  width: 70,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
                const SizedBox(width: 4),
                Text(context.l10n.dive3d_tissue_offGassing, style: text),
              ],
            ),
            const SizedBox(height: 4),
            Text(context.l10n.dive3d_tissue_legendHeight, style: text),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 3, color: const Color(0xFFEF5350)),
                const SizedBox(width: 6),
                Text(context.l10n.dive3d_tissue_legendLimit, style: text),
              ],
            ),
            const SizedBox(height: 2),
            Text(context.l10n.dive3d_tissue_legendAxes, style: text),
          ],
        ),
      ),
    );
  }
}
