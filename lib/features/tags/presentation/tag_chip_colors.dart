import 'package:flutter/material.dart';

/// The three colours a tag chip is painted with (issue #2269).
typedef TagChipColors = ({Color fill, Color border, Color label});

/// How much of the tag's colour the fill carries.
///
/// One value, not the 0.15 a dive row used and the 0.2 a detail card used:
/// two tints give a tag two display colours, and a swatch in Settings can
/// only tell the truth about one of them.
const double _fillTint = 0.15;

/// WCAG 2.1 AA for body text.
const double _minLabelContrast = 4.5;

/// How finely the label's lightness is searched. Enough steps that a colour
/// moves no further than it has to.
const int _labelSteps = 20;

/// The colours a tag chip paints for a tag whose stored colour is [seed].
///
/// A tag chip is a quiet tint of the diver's colour rather than a chip
/// flooded with it, which is how tags looked before #2255 and how they look
/// again. The difference is that the tint is resolved here, once, against the
/// theme's own surface and returned opaque.
///
/// That matters beyond tidiness. A translucent fill is not a colour but a
/// recipe whose result depends on whatever is painted behind it, so the same
/// tag used to come out four different colours across the app and a fifth on
/// a selected row, where the row's blue-grey bled through (issue #2254).
/// Resolving the tint here means a tag has exactly one display colour, which
/// is what lets the Settings swatches offer it.
///
/// [ColorScheme.surface] is a deliberate fixed reference, not an oversight:
/// a chip on a card sits on `surfaceContainerLow` or higher, and tinting
/// against whichever container the chip happens to be in would hand back a
/// different colour per surface, which is the bug this exists to prevent. The
/// chip is meant to read as a chip against its background rather than as a
/// wash of it, and the full-strength border carries the identity either way.
/// `course_status_colors.dart` names its own surface for the same reason, and
/// names the one its card actually uses because that card has only one home.
TagChipColors tagChipColors(BuildContext context, Color seed) =>
    tagChipColorsFor(
      seed: seed,
      surface: Theme.of(context).colorScheme.surface,
    );

/// [tagChipColors] without a [BuildContext], for callers that already hold
/// the scheme and for tests that need to name the surface they are checking.
TagChipColors tagChipColorsFor({required Color seed, required Color surface}) {
  final fill = Color.alphaBlend(seed.withValues(alpha: _fillTint), surface);
  return (fill: fill, border: seed, label: _labelOn(fill, seed));
}

/// The label colour for a chip filled with [fill] by a tag coloured [seed].
///
/// The pre-#2255 chips wrote the label in the raw [seed], which on its own
/// 15 per cent tint is about 1.7:1 for the pale end of the palette: legible
/// in theory, invisible in practice. #2255 answered that with black or white,
/// which reads but drops the tag's identity from the text.
///
/// The seed instead keeps its hue and its saturation and gives up only
/// lightness, moving away from the fill until it clears AA. Working in HSL
/// rather than blending towards a dark neutral matters: an RGB blend
/// compresses the channel spread, which cost the saturated mid tones such as
/// `#A855F7` nearly half their saturation on the way down.
///
/// The direction is read off the fill alone, so the one rule serves both
/// themes: the label darkens on a pale chip and lightens on a dark one.
///
/// It is read off the fill rather than off the fill against the seed, which
/// is a distinction that only shows up at the ends of the range. A tag stored
/// near black on a dark theme has a fill LIGHTER than itself, because the
/// fill is mostly surface; comparing the two then walked the label towards
/// black, into the fill, and left it at 1.1:1. A white tag on a light theme
/// was worse still, white on white at 1.0:1.
Color _labelOn(Color fill, Color seed) {
  if (tagContrastRatio(seed, fill) >= _minLabelContrast) return seed;

  final hsl = HSLColor.fromColor(seed);

  // Whichever end of the lightness range has room against this fill. Black
  // clears AA for any fill above about 0.175 luminance and white for any
  // below about 0.183, so the two ranges overlap: some end always works,
  // whatever the fill, and the walk below always terminates.
  final endpoint =
      tagContrastRatio(Colors.black, fill) >=
          tagContrastRatio(Colors.white, fill)
      ? 0.0
      : 1.0;

  for (var step = 1; step < _labelSteps; step++) {
    final t = step / _labelSteps;
    final candidate = hsl
        .withLightness(hsl.lightness + (endpoint - hsl.lightness) * t)
        .toColor();
    if (tagContrastRatio(candidate, fill) >= _minLabelContrast) {
      return candidate;
    }
  }
  return hsl.withLightness(endpoint).toColor();
}

/// WCAG 2.1 contrast ratio between two opaque colours, from 1 (identical) to
/// 21 (black on white).
double tagContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
