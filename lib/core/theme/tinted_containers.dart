import 'package:flutter/material.dart';

/// Strength of the accent tint laid over the surface to form a container.
///
/// Dark surfaces need a stronger tint for the container to read as a distinct
/// fill; both strengths keep ordinary onSurface text well above WCAG AA on
/// every hand-built preset (test/core/theme/theme_container_contrast_test.dart).
const double _lightTint = 0.16;
const double _darkTint = 0.28;

/// Fills in the container roles of a hand-built [ColorScheme].
///
/// The plain [ColorScheme] constructor falls back to the accent itself for an
/// omitted container (primaryContainer becomes primary, onPrimaryContainer
/// becomes onPrimary). Widgets treat containers as low-emphasis fills and
/// often draw ordinary body text on them, so a bright accent there left white
/// text on light teal in the Console theme (#2959). [ColorScheme.fromSeed]
/// avoids this but regenerates the accents too, saturating near-grey ones.
///
/// Each container here is its accent tinted over the scheme's own surface, so
/// it keeps the theme's hue and stays close to the surface in lightness, and
/// its foreground is the scheme's onSurface.
///
/// [secondaryAccent] replaces the secondary accent as the tint source for
/// secondaryContainer. Material draws selection indicators (navigation
/// indicators, selected segments and chips) in it, so a theme passes this to
/// give them a different accent; Console dark tints them from its teal primary
/// rather than its slate secondary.
ColorScheme withTintedContainers(ColorScheme scheme, {Color? secondaryAccent}) {
  final tint = scheme.brightness == Brightness.dark ? _darkTint : _lightTint;
  Color container(Color accent) =>
      Color.alphaBlend(accent.withValues(alpha: tint), scheme.surface);

  return scheme.copyWith(
    primaryContainer: container(scheme.primary),
    onPrimaryContainer: scheme.onSurface,
    secondaryContainer: container(secondaryAccent ?? scheme.secondary),
    onSecondaryContainer: scheme.onSurface,
    tertiaryContainer: container(scheme.tertiary),
    onTertiaryContainer: scheme.onSurface,
    errorContainer: container(scheme.error),
    onErrorContainer: scheme.onSurface,
  );
}
