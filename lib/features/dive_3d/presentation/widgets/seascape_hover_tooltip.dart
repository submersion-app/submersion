import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_surface.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Compact readout for a hovered seascape terrain vertex: latitude and
/// longitude (5 decimals), plus the seafloor depth in the diver's units.
/// Land and nodata cells show an em-dash for depth. Mirrors the tissue
/// view's hover tooltip.
class SeascapeHoverTooltip extends ConsumerWidget {
  final TissuePick pick;
  final BathymetryGrid grid;

  const SeascapeHoverTooltip({
    super.key,
    required this.pick,
    required this.grid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A pick can go stale if the terrain refreshes to a smaller grid before
    // the overlay rebuilds; never index out of range.
    if (pick.col >= grid.rows || pick.comp >= grid.cols) {
      return const SizedBox.shrink();
    }
    final info = seascapeCellInfo(grid, pick);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final depth = info.depthMeters;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;

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
              '${info.latitude.toStringAsFixed(5)}, '
              '${info.longitude.toStringAsFixed(5)}',
              style: text,
            ),
            const SizedBox(height: 2),
            Text(depth == null ? '—' : units.formatDepth(depth), style: text),
          ],
        ),
      ),
    );
  }
}
