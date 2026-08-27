import 'package:flutter/widgets.dart';

/// Collapses a font's default ascent/descent leading so a [Text]'s ink sits
/// centered in a tight box, instead of leaning on the font's own (often
/// asymmetric) leading. Pair with [InkCenteredTextStyle.inkCentered] on the
/// [Text]'s `style`.
///
/// Needed for short, isolated text next to a box-tight sibling (an icon, a
/// bordered badge) -- the offset is invisible until something else on the
/// same line gives the eye a true center line to compare against.
const inkCenteredTextHeightBehavior = TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: false,
);

extension InkCenteredTextStyle on TextStyle {
  /// This style with `height` pinned to 1, for use with
  /// [inkCenteredTextHeightBehavior].
  TextStyle get inkCentered => copyWith(height: 1);

  /// A [StrutStyle] that reserves this (pre-[inkCentered]) style's own line
  /// height, so switching a [Text] to [inkCentered] repositions its ink
  /// without shrinking the space it occupies in its parent layout -- e.g. a
  /// title line above a sibling line, which would otherwise shift up.
  StrutStyle get preservingStrut =>
      StrutStyle(fontSize: fontSize, height: height, forceStrutHeight: true);
}
