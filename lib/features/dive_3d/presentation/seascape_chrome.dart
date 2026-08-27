import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

/// Theme-derived colors for the seascape's axis chrome. A single neutral
/// tone for all three axes: the seascape's axes are measurement chrome
/// over a scenic view, not a chart triad. (`TissueChromeStyle` is reused
/// as the shared color-set type; the wireframe/marker slots are unused by
/// the axis-only painter.)
TissueChromeStyle seascapeChromeStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final axis = scheme.onSurface.withValues(alpha: 0.75);
  return TissueChromeStyle(
    axisX: axis,
    axisY: axis,
    axisZ: axis,
    grid: scheme.outline.withValues(alpha: 0.18),
    wireframe: Colors.transparent,
    marker: scheme.onSurface,
    markerOutline: scheme.surface,
    label: scheme.onSurface,
  );
}
