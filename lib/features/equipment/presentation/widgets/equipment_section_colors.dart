import 'package:flutter/material.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';

export 'package:submersion/core/theme/contrast_ratio.dart' show contrastRatio;

/// The contrast WCAG AA requires of body text.
const double _kReadable = 4.5;

/// Colour picks the Equipment screens make against a theme's actual
/// surfaces rather than fixed roles, because the roles do not hold up across
/// the app's themes. In nine of the ten preset schemes `onSurfaceVariant` is
/// identical to `onSurface`, so a "dimmer role" is not dimmer at all.
///
/// The Equipment / Sets switch drew its selected section on a pill in these
/// colours until it took the Media tabs' underline (issue #3465); the figure
/// still draws its labels and badges with [readableOn].
abstract final class EquipmentSectionColors {
  /// The candidate that reads best on [fill], or black or white if none of
  /// them reads well enough.
  ///
  /// `onSecondaryContainer` is the pairing a theme is meant to guarantee, but
  /// two of the app's presets break it (2.95:1 and 4.10:1).
  static Color readableOn(Color fill, List<Color> candidates) {
    final best = candidates.reduce(
      (a, b) => contrastRatio(a, fill) >= contrastRatio(b, fill) ? a : b,
    );
    if (contrastRatio(best, fill) >= _kReadable) return best;
    return contrastRatio(Colors.black, fill) >=
            contrastRatio(Colors.white, fill)
        ? Colors.black
        : Colors.white;
  }
}
