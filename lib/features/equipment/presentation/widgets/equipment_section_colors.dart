import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 2.x contrast ratio between two colours: 1 for identical, 21 for black
/// on white.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The contrast WCAG AA requires of body text.
const double _kReadable = 4.5;

/// A little above [_kReadable], so the dimmed name keeps its margin once the
/// colour is quantised for display.
const double _kDimFloor = 4.6;

/// The colours the Equipment / Sets title draws its selection with.
///
/// Resolved against the scheme's actual surfaces rather than taken from fixed
/// roles, because the roles do not hold up across the app's themes. In nine
/// of the ten preset schemes `onSurfaceVariant` is identical to `onSurface`,
/// so a "dimmer role" is not dimmer; in the default dark scheme the two are
/// only 1.31:1 apart, which is what made the selected section impossible to
/// pick out.
class EquipmentSectionColors {
  const EquipmentSectionColors._({
    required this.pill,
    required this.selected,
    required this.unselected,
  });

  factory EquipmentSectionColors.of(ColorScheme scheme) {
    // NavigationRail's default indicator, so this selection matches the
    // sidebar's.
    final pill = scheme.secondaryContainer;
    return EquipmentSectionColors._(
      pill: pill,
      selected: _readableOn(pill, [
        scheme.onSecondaryContainer,
        scheme.onSurface,
      ]),
      unselected: _dimmestReadable(scheme.onSurface, [
        scheme.surface,
        // The phone app bar takes this tint once the list scrolls under it.
        scheme.surfaceContainer,
      ]),
    );
  }

  /// Behind the selected section's name.
  final Color pill;

  /// The selected section's name, on [pill].
  final Color selected;

  /// The other section's name, on the header's own surface.
  final Color unselected;

  /// The dimmest blend of [text] over the first of [surfaces] that still
  /// reads as text on every one of them.
  ///
  /// The walk starts at 30% so the name never fades to a ghost, even in a
  /// theme where a fainter blend would technically pass. The result is an
  /// opaque colour, not a tint.
  static Color _dimmestReadable(Color text, List<Color> surfaces) {
    for (var percent = 30; percent < 100; percent++) {
      final blend = Color.alphaBlend(
        text.withValues(alpha: percent / 100),
        surfaces.first,
      );
      if (surfaces.every((s) => contrastRatio(blend, s) >= _kDimFloor)) {
        return blend;
      }
    }
    return text;
  }

  /// The candidate that reads best on [fill], or black or white if none of
  /// them reads well enough.
  ///
  /// `onSecondaryContainer` is the pairing a theme is meant to guarantee, but
  /// two of the app's presets break it (2.95:1 and 4.10:1).
  static Color _readableOn(Color fill, List<Color> candidates) {
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
