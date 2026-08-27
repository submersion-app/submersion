import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact depth legend for the seascape views: the terrain color ramp
/// (continuous or banded, honoring a custom ramp range with a "+" cap when
/// deeper terrain clamps) plus a land swatch when the grid has any.
class SeascapeDepthLegend extends StatelessWidget {
  final double maxDepthMeters;
  final bool hasLand;
  final SeascapeAppearance appearance;
  final double displayUnitInMeters;
  final String depthSymbol;

  const SeascapeDepthLegend({
    super.key,
    required this.maxDepthMeters,
    required this.hasLand,
    required this.appearance,
    required this.displayUnitInMeters,
    required this.depthSymbol,
  });

  static const double _barHeight = 96;
  static const double _barWidth = 12;

  String _depthText(double meters, {bool clamped = false}) {
    final v = meters / displayUnitInMeters;
    final text = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return clamped ? '$text+ $depthSymbol' : '$text $depthSymbol';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rampMax = appearance.rampMaxDepthMeters ?? maxDepthMeters;
    final clamped =
        appearance.rampMaxDepthMeters != null &&
        appearance.rampMaxDepthMeters! < maxDepthMeters;
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    final bar = appearance.rampBanded
        ? Column(
            key: const ValueKey('seascapeLegendBandedBar'),
            children: [
              for (var i = 0; i < 10; i++)
                Expanded(
                  child: ColoredBox(
                    color: BathymetryTerrainBuilder.depthColor(
                      (i + 0.5) / 10,
                      banded: true,
                    ),
                    child: const SizedBox(width: _barWidth),
                  ),
                ),
            ],
          )
        : const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  BathymetryTerrainBuilder.shallowColor,
                  BathymetryTerrainBuilder.deepColor,
                ],
              ),
            ),
            child: SizedBox(width: _barWidth, height: _barHeight),
          );

    return Container(
      key: const ValueKey('seascapeDepthLegend'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: _barWidth,
                  height: _barHeight,
                  child: bar,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: _barHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_depthText(0), style: labelStyle),
                    Text(
                      _depthText(rampMax, clamped: clamped),
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasLand) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const ColoredBox(
                    color: BathymetryTerrainBuilder.landColor,
                    child: SizedBox(width: 12, height: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.dive3d_seascape_legend_land,
                  style: labelStyle,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
