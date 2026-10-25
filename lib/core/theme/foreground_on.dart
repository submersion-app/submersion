import 'package:flutter/material.dart';

/// The colour for text and icons drawn on a solid [fill].
///
/// A fill taken from one of [scheme]'s accent roles gets that role's paired
/// foreground, which test/core/theme/theme_container_contrast_test.dart holds
/// at WCAG AA on every preset. Dark themes make those accents light tones, so
/// a fixed white label on them read at about 1.5:1.
///
/// Any other fill (a fixed status hue such as green or orange) gets black or
/// white, whichever contrasts more with it.
Color foregroundOn(ColorScheme scheme, Color fill) {
  if (fill == scheme.primary) return scheme.onPrimary;
  if (fill == scheme.secondary) return scheme.onSecondary;
  if (fill == scheme.tertiary) return scheme.onTertiary;
  if (fill == scheme.error) return scheme.onError;

  // WCAG contrast against white is 1.05 / (L + 0.05) and against black is
  // (L + 0.05) / 0.05; they are equal where L is about 0.179.
  final luminance = fill.computeLuminance();
  return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05)
      ? Colors.black
      : Colors.white;
}
