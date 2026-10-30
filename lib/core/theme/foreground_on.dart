import 'package:flutter/material.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';

/// The colour for text and icons drawn on a solid [fill].
///
/// A fill taken from one of [scheme]'s accent roles gets that role's paired
/// foreground, which test/core/theme/theme_container_contrast_test.dart holds
/// at WCAG AA on every preset. Dark themes make those accents light tones, so
/// a fixed white label on them read at about 1.5:1.
///
/// Any other fill (a fixed status hue such as green or orange) gets black or
/// white from [blackOrWhiteOn].
Color foregroundOn(ColorScheme scheme, Color fill) {
  if (fill == scheme.primary) return scheme.onPrimary;
  if (fill == scheme.secondary) return scheme.onSecondary;
  if (fill == scheme.tertiary) return scheme.onTertiary;
  if (fill == scheme.error) return scheme.onError;
  return blackOrWhiteOn(fill);
}

/// Black or white, whichever contrasts more with [fill]: the foreground for
/// a fill that is data rather than a theme role (a kind or group colour, a
/// fixed status hue).
Color blackOrWhiteOn(Color fill) =>
    contrastRatio(Colors.black, fill) >= contrastRatio(Colors.white, fill)
    ? Colors.black
    : Colors.white;
