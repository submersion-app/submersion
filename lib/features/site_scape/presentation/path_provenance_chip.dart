import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_active_path_overlay_builder.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The caption stating where a played-back path's shape came from: a
/// linked measured route reads as a recorded route, dead reckoning and the
/// straight-line fallback keep the honest "estimated" label. Shared by
/// [PathProvenanceChip] and the standalone dive seascape's captions so the
/// two views never word the same path differently.
String pathProvenanceLabel(
  BuildContext context,
  PathProvenance provenance,
  String? sourceLabel,
) => switch (provenance) {
  PathProvenance.measured =>
    sourceLabel != null
        ? context.l10n.dive3d_spatial_recordedTrackWithSource(sourceLabel)
        : context.l10n.dive3d_spatial_recordedTrack,
  PathProvenance.deadReckoned ||
  PathProvenance.straightLine => context.l10n.dive3d_spatial_estimatedPath,
};

/// States where a played-back path's shape came from (see
/// [pathProvenanceLabel]). Dive-only at the call site (`SiteTerrainPane`)
/// -- a route has no such caption, it IS the recorded path.
class PathProvenanceChip extends StatelessWidget {
  final SiteActivePathOverlay overlay;

  const PathProvenanceChip({super.key, required this.overlay});

  @override
  Widget build(BuildContext context) => SeascapeCaptionChip(
    label: pathProvenanceLabel(
      context,
      overlay.provenance,
      overlay.pathSourceLabel,
    ),
  );
}

/// One honest-caption chip over a seascape (info icon plus a short
/// label), pinned to the top-left of whatever space it is given.
class SeascapeCaptionChip extends StatelessWidget {
  final String label;

  const SeascapeCaptionChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
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
            // Flexible: a route's source label can be a long device or
            // file name, wider than a phone-width pane; it wraps instead
            // of overflowing the Row.
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}
