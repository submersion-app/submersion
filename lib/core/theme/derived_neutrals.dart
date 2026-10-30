import 'package:flutter/material.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';

/// How far each tonal surface container steps from the surface toward
/// onSurface. The seeded presets' highest container sits about 1.2:1 from
/// their surface; these land the hand-built presets in the same range.
const double _containerStep = 0.05;
const double _containerHighStep = 0.08;
const double _containerHighestStep = 0.11;

/// How far the lowest container steps the other way, toward white on a light
/// page and black on a dark one. Material 3 puts it there (tone 100 over a
/// tone-98 surface in light, 4 under 6 in dark).
const double _containerLowestStep = 0.6;

/// How strongly the decorative hairline (dividers, card edges) is drawn.
const double _outlineVariantStrength = 0.20;

/// Floor for onSurfaceVariant on every surface. WCAG AA (4.5) alone left it
/// near 5.7:1, far fainter than the seeded presets' 9 to 11; AAA (7) keeps
/// secondary text close to them while still a clear step below onSurface.
const double _variantText = 7.0;

/// WCAG minimum for meaningful non-text marks (borders, focus rings).
const double _readableMark = 3.0;

/// Fills in the neutral roles a hand-built [ColorScheme] left unset.
///
/// The plain [ColorScheme] constructor falls back to onSurface for an
/// omitted onSurfaceVariant, outline and outlineVariant, and to the surface
/// for every omitted surfaceContainer. So in the hand-built presets "muted"
/// text was not muted, a hairline divider was a full-contrast line and a
/// tonal fill was invisible against the page. [ColorScheme.fromSeed] derives
/// these from tonal palettes; this derives them from the scheme's own
/// surface and onSurface, so they keep the preset's hue.
///
/// - surfaceContainer, High and Highest step from the surface toward
///   onSurface, and Lowest steps the other way. surfaceContainerLow is left
///   alone: the presets use it as their card colour.
/// - onSurfaceVariant is the quietest blend of onSurface that still reads at
///   7:1 on the surface and on every container.
/// - outline is the quietest blend that still marks a boundary (3:1) on the
///   surface and the highest container; outlineVariant is a faint hairline.
///
/// test/core/theme/theme_neutral_roles_test.dart holds these on every preset.
ColorScheme withDerivedNeutrals(ColorScheme scheme) {
  Color toward(double strength) => Color.alphaBlend(
    scheme.onSurface.withValues(alpha: strength),
    scheme.surface,
  );

  // Only a role still at Flutter's fallback is derived; one the preset sets
  // itself is kept. The containers fall back to the surface, the rest to
  // onSurface (outline via onBackground, which the presets leave unset).
  Color container(Color role, double strength) =>
      role == scheme.surface ? toward(strength) : role;
  Color ink(Color role, Color Function() derive) =>
      role == scheme.onSurface ? derive() : role;

  final surfaceContainer = container(scheme.surfaceContainer, _containerStep);
  final containerHigh = container(
    scheme.surfaceContainerHigh,
    _containerHighStep,
  );
  final containerHighest = container(
    scheme.surfaceContainerHighest,
    _containerHighestStep,
  );
  final containerLowest = scheme.surfaceContainerLowest == scheme.surface
      ? Color.alphaBlend(
          (scheme.brightness == Brightness.light ? Colors.white : Colors.black)
              .withValues(alpha: _containerLowestStep),
          scheme.surface,
        )
      : scheme.surfaceContainerLowest;

  /// The quietest blend of onSurface that reaches [minimum] on every
  /// colour in [backgrounds].
  Color quietest(double minimum, List<Color> backgrounds) {
    for (var percent = 30; percent < 100; percent++) {
      final candidate = toward(percent / 100);
      if (backgrounds.every((bg) => contrastRatio(candidate, bg) >= minimum)) {
        return candidate;
      }
    }
    return scheme.onSurface;
  }

  return scheme.copyWith(
    surfaceContainerLowest: containerLowest,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: containerHigh,
    surfaceContainerHighest: containerHighest,
    onSurfaceVariant: ink(
      scheme.onSurfaceVariant,
      () => quietest(_variantText, [
        scheme.surface,
        scheme.surfaceContainerLow,
        surfaceContainer,
        containerHigh,
        containerHighest,
      ]),
    ),
    outline: ink(
      scheme.outline,
      () => quietest(_readableMark, [scheme.surface, containerHighest]),
    ),
    outlineVariant: ink(
      scheme.outlineVariant,
      () => toward(_outlineVariantStrength),
    ),
  );
}
