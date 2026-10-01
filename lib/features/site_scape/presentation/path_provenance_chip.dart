import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_active_path_overlay_builder.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// States where a played-back path's shape came from: a linked measured
/// route reads as a recorded route, dead reckoning and the straight-line
/// fallback keep the honest "estimated" label. Dive-only at the call site
/// (`SiteTerrainPane`) -- a route has no such caption, it IS the recorded
/// path.
class PathProvenanceChip extends StatelessWidget {
  final SiteActivePathOverlay overlay;

  const PathProvenanceChip({super.key, required this.overlay});

  @override
  Widget build(BuildContext context) {
    final label = switch (overlay.provenance) {
      PathProvenance.measured =>
        overlay.pathSourceLabel != null
            ? context.l10n.dive3d_spatial_recordedPathWithSource(
                overlay.pathSourceLabel!,
              )
            : context.l10n.dive3d_spatial_recordedPath,
      PathProvenance.deadReckoned ||
      PathProvenance.straightLine => context.l10n.dive3d_spatial_estimatedPath,
    };
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
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
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
