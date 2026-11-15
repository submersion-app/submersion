import 'package:flutter/material.dart';

/// Opacity of the light rim drawn along the pinned strip's sides and bottom
/// in dark mode, where a shadow alone barely darkens the page (#4554).
const double kPinnedStripRimAlpha = 0.12;

/// One layer of the strip's shadow at full strength.
typedef _Layer = ({double alpha, double dy, double blur});

/// Light: a tight contact shadow and a soft, deep drop, clearly above the
/// cards it covers (elevation 0 to 4 across the theme presets).
const List<_Layer> _lightLayers = [
  (alpha: 0.18, dy: 2, blur: 4),
  (alpha: 0.24, dy: 10, blur: 22),
];

/// Dark: black barely darkens a near-black page, so far more of it.
const List<_Layer> _darkLayers = [
  (alpha: 0.65, dy: 2, blur: 6),
  (alpha: 0.70, dy: 12, blur: 28),
];

/// The pinned strip's shadows for [brightness], at [strength] from 0 (none)
/// to 1 (settled).
///
/// Opacity shrinks with offset and blur: scaling the size alone would leave
/// a hard, fully dark line as the strip starts to condense.
List<BoxShadow> pinnedStripShadows(
  Brightness brightness, {
  required double strength,
}) {
  final s = strength.clamp(0.0, 1.0);
  if (s == 0) return const [];
  final layers = brightness == Brightness.dark ? _darkLayers : _lightLayers;
  return [
    for (final l in layers)
      BoxShadow(
        color: Colors.black.withValues(alpha: l.alpha * s),
        offset: Offset(0, l.dy * s),
        blurRadius: l.blur * s,
      ),
  ];
}

/// How far beyond the strip's sides and bottom its shadow may fall: room for
/// the deepest layer (dark: offset 12 plus blur 28) with some to spare.
const double kPinnedStripShadowReach = 64;

/// Clips the strip's shadow at the strip's own top edge, letting it fall
/// freely beside and below. Mid-condense the strip's top crosses the profile
/// card, and pinned it sits under the header: a blurred shadow rising above
/// it would grey both.
class PinnedStripShadowClip extends CustomClipper<Rect> {
  const PinnedStripShadowClip();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -kPinnedStripShadowReach,
    0,
    size.width + kPinnedStripShadowReach,
    size.height + kPinnedStripShadowReach,
  );

  @override
  bool shouldReclip(PinnedStripShadowClip oldClipper) => false;
}

/// The line along the strip's sides and bottom.
///
/// Where the theme's cards have an outline ([themeSide]) the strip keeps it,
/// fading in with the surface ([surfaceOpacity]); a rim on top of it would
/// draw a second line. Otherwise, in dark mode only, a faint light rim marks
/// the strip's edge, growing in with [strength].
BorderSide pinnedStripEdge({
  required Brightness brightness,
  required BorderSide themeSide,
  required double surfaceOpacity,
  required double strength,
}) {
  if (themeSide.style != BorderStyle.none && themeSide.width > 0) {
    return themeSide.copyWith(
      color: themeSide.color.withValues(
        alpha: themeSide.color.a * surfaceOpacity.clamp(0.0, 1.0),
      ),
    );
  }
  final s = strength.clamp(0.0, 1.0);
  if (brightness != Brightness.dark || s == 0) return BorderSide.none;
  return BorderSide(
    color: Colors.white.withValues(alpha: kPinnedStripRimAlpha * s),
  );
}
