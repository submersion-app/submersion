import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

/// Theme-derived colors for the path scene's chrome: one neutral tone for
/// all three axes (this is a measurement frame, not a color-coded triad),
/// a faint grid, theme label color. Red stays reserved for the ceiling
/// violation inside the scene.
TissueChromeStyle diveChromeStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final axis = scheme.onSurface.withValues(alpha: 0.8);
  return TissueChromeStyle(
    axisX: axis,
    axisY: axis,
    axisZ: axis,
    grid: scheme.outline.withValues(alpha: 0.22),
    wireframe: Colors.transparent,
    marker: scheme.onSurface,
    markerOutline: scheme.surface,
    label: scheme.onSurface,
  );
}
