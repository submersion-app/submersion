import 'package:flutter/painting.dart';

import 'package:submersion/core/theme/contrast_ratio.dart';

/// Contrast the depth colour must reach against a card to keep it.
///
/// Below WCAG's 3:1 for graphics on purpose: the default depth blue sits at
/// about 2.5:1 on the plain dark-mode card and reads clearly there, while the
/// mid-range tints of the card colour gradients, where it disappears, fall
/// between 1.1:1 and 1.5:1.
const double miniChartMinContrast = 2.0;

/// The colour a dive list card's mini profile chart is drawn in.
///
/// The full chart's [depthColor], so a dive reads the same in the list as on
/// its detail page, unless it falls under [miniChartMinContrast] against the
/// card's [background]. Then the more legible of it and [fallback] (the
/// card's own accent, picked for the background) wins, so the swap never
/// makes the line harder to see.
Color miniChartLineColor({
  required Color depthColor,
  required Color fallback,
  required Color background,
}) {
  final depthContrast = contrastRatio(depthColor, background);
  if (depthContrast >= miniChartMinContrast) return depthColor;
  return contrastRatio(fallback, background) > depthContrast
      ? fallback
      : depthColor;
}
